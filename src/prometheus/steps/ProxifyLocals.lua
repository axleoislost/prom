-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- StringifyGlobals.lua
--
-- Stringifies all global references and string index accesses.
-- One global env = getfenv() at the top, one strVar local per reference.

local Step     = require("prometheus.step");
local Ast      = require("prometheus.ast");
local Scope    = require("prometheus.scope");
local visitast = require("prometheus.visitast");

local AstKind = Ast.AstKind;

local StringifyGlobals = Step:extend();
StringifyGlobals.Description = "Turns every global reference and string index into strVar locals";
StringifyGlobals.Name = "Stringify Globals";

StringifyGlobals.SettingsDescriptor = {
	Treshold = {
		name = "Treshold",
		description = "The relative amount of references that will be affected",
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
};

function StringifyGlobals:init(settings)
end

-- Return a direct string index (no local needed)
local function makeStrIndex(name)
	return Ast.StringExpression(name);
end

local function walkExpr(expr, blockScope, treshold, injections)
	if not expr or type(expr) ~= "table" or not expr.kind then return expr end

	-- Global variable: print, Vector3, task ...
	-- Use a strVar local so unparser is forced to use bracket notation: env[a]
	if expr.kind == AstKind.VariableExpression and expr.scope and expr.scope.isGlobal then
		if math.random() > treshold then return expr end
		local name = expr.scope:getVariableName(expr.id);
		if not name or name == "getfenv" or name == "_ENV" then return expr end
		local strVar = blockScope:addVariable();
		table.insert(injections, { strVar = strVar, name = name });
		return { __envIndex = true, strVar = strVar, blockScope = blockScope };
	end

	-- String index: recurse into base and index
	if expr.kind == AstKind.IndexExpression then
		expr.base = walkExpr(expr.base, blockScope, treshold, injections);
		if type(expr.index) == "table" and expr.index.kind ~= nil then
			expr.index = walkExpr(expr.index, blockScope, treshold, injections);
		end
		return expr;
	end

	-- PassSelf call expression: leave as-is to preserve self semantics
	if expr.kind == AstKind.PassSelfFunctionCallExpression then
		expr.base = walkExpr(expr.base, blockScope, treshold, injections);
		if expr.args then
			for i, arg in ipairs(expr.args) do
				expr.args[i] = walkExpr(arg, blockScope, treshold, injections);
			end
		end
		return expr;
	end

	-- Generic recursion
	if expr.base   ~= nil then expr.base  = walkExpr(expr.base,  blockScope, treshold, injections) end
	if expr.lhs    ~= nil then expr.lhs   = walkExpr(expr.lhs,   blockScope, treshold, injections) end
	if expr.rhs    ~= nil then expr.rhs   = walkExpr(expr.rhs,   blockScope, treshold, injections) end
	if expr.args   ~= nil then
		for i, arg in ipairs(expr.args) do
			expr.args[i] = walkExpr(arg, blockScope, treshold, injections);
		end
	end
	if expr.values ~= nil then
		for i, v in ipairs(expr.values) do
			expr.values[i] = walkExpr(v, blockScope, treshold, injections);
		end
	end
	if expr.entries ~= nil then
		for i, entry in ipairs(expr.entries) do
			expr.entries[i] = walkExpr(entry, blockScope, treshold, injections);
		end
	end

	return expr;
end

-- Resolve __envIndex -> env["name"], __localPlaceholder -> strVar
local function resolve(expr, envScope, envId)
	if not expr or type(expr) ~= "table" then return expr end
	if expr.__envIndex then
		expr.blockScope:addReferenceToHigherScope(envScope, envId);
		return Ast.IndexExpression(
			Ast.VariableExpression(envScope, envId),
			Ast.VariableExpression(expr.blockScope, expr.strVar)
		);
	end
	if expr.__localPlaceholder then
		return Ast.VariableExpression(expr.blockScope, expr.strVar);
	end

	if expr.base   ~= nil then expr.base  = resolve(expr.base,  envScope, envId) end
	if expr.index  ~= nil and type(expr.index) == "table" then
		expr.index = resolve(expr.index, envScope, envId)
	end
	if expr.lhs    ~= nil then expr.lhs   = resolve(expr.lhs,   envScope, envId) end
	if expr.rhs    ~= nil then expr.rhs   = resolve(expr.rhs,   envScope, envId) end
	if expr.args   ~= nil then
		for i, arg in ipairs(expr.args) do
			expr.args[i] = resolve(arg, envScope, envId);
		end
	end
	if expr.values ~= nil then
		for i, v in ipairs(expr.values) do
			expr.values[i] = resolve(v, envScope, envId);
		end
	end
	if expr.entries ~= nil then
		for i, entry in ipairs(expr.entries) do
			expr.entries[i] = resolve(entry, envScope, envId);
		end
	end

	return expr;
end

local function walkStat(stat, blockScope, treshold, injections)
	if not stat then return end
	local k = stat.kind;

	if k == AstKind.FunctionCallStatement then
		stat.base = walkExpr(stat.base, blockScope, treshold, injections);
		if stat.args then
			for i, arg in ipairs(stat.args) do
				stat.args[i] = walkExpr(arg, blockScope, treshold, injections);
			end
		end

	elseif k == AstKind.PassSelfFunctionCallStatement then
		-- Leave PassSelf as-is to preserve self semantics
		stat.base = walkExpr(stat.base, blockScope, treshold, injections);
		if stat.args then
			for i, arg in ipairs(stat.args) do
				stat.args[i] = walkExpr(arg, blockScope, treshold, injections);
			end
		end

	elseif k == AstKind.LocalVariableDeclaration then
		if stat.expressions then
			for i, v in ipairs(stat.expressions) do
				stat.expressions[i] = walkExpr(v, blockScope, treshold, injections);
			end
		end

	elseif k == AstKind.AssignmentStatement then
		if stat.lhs then
			for i, lh in ipairs(stat.lhs) do
				if lh.kind == AstKind.AssignmentIndexing then
					-- base: the object being indexed
					lh.base = walkExpr(lh.base, blockScope, treshold, injections);
					-- index: the key (may be StringExpression for obj.field = ...)
					if lh.index and lh.index.kind ~= AstKind.StringExpression then
						lh.index = walkExpr(lh.index, blockScope, treshold, injections);
					end
				elseif lh.kind == AstKind.AssignmentVariable and lh.scope and lh.scope.isGlobal then
					-- global assignment: x = ... -> env["x"] = ...
					if math.random() <= treshold then
						local name = lh.scope:getVariableName(lh.id);
						if name and name ~= "getfenv" and name ~= "_ENV" then
							lh.__globalName = name;
							lh.__globalBlockScope = blockScope;
						end
					end
				end
			end
		end
		if stat.rhs then
			for i, v in ipairs(stat.rhs) do
				stat.rhs[i] = walkExpr(v, blockScope, treshold, injections);
			end
		end

	elseif k == AstKind.ReturnStatement then
		if stat.args then
			for i, arg in ipairs(stat.args) do
				stat.args[i] = walkExpr(arg, blockScope, treshold, injections);
			end
		end

	elseif k == AstKind.IfStatement then
		if stat.condition then
			stat.condition = walkExpr(stat.condition, blockScope, treshold, injections);
		end
		-- elseif branches
		if stat.elseifs then
			for _, elif in ipairs(stat.elseifs) do
				if elif.condition then
					elif.condition = walkExpr(elif.condition, blockScope, treshold, injections);
				end
			end
		end

	elseif k == AstKind.WhileStatement then
		if stat.condition then
			stat.condition = walkExpr(stat.condition, blockScope, treshold, injections);
		end

	elseif k == AstKind.RepeatStatement then
		if stat.condition then
			stat.condition = walkExpr(stat.condition, blockScope, treshold, injections);
		end

	elseif k == AstKind.ForStatement then
		if stat.start  then stat.start  = walkExpr(stat.start, blockScope, treshold, injections) end
		if stat.stop   then stat.stop   = walkExpr(stat.stop, blockScope, treshold, injections) end
		if stat.step   then stat.step   = walkExpr(stat.step, blockScope, treshold, injections) end

	elseif k == AstKind.ForInStatement then
		if stat.iterators then
			for i, iter in ipairs(stat.iterators) do
				stat.iterators[i] = walkExpr(iter, blockScope, treshold, injections);
			end
		end
	end
end

local function resolveStatPlaceholders(stat, envScope, envId)
	if not stat then return end
	local k = stat.kind;

	if k == AstKind.FunctionCallStatement then
		stat.base = resolve(stat.base, envScope, envId);
		if stat.args then
			for i, arg in ipairs(stat.args) do
				stat.args[i] = resolve(arg, envScope, envId);
			end
		end

	elseif k == AstKind.PassSelfFunctionCallStatement then
		stat.base = resolve(stat.base, envScope, envId);
		if stat.args then
			for i, arg in ipairs(stat.args) do
				stat.args[i] = resolve(arg, envScope, envId);
			end
		end


	elseif k == AstKind.LocalVariableDeclaration then
		if stat.expressions then
			for i, v in ipairs(stat.expressions) do
				stat.expressions[i] = resolve(v, envScope, envId);
			end
		end

	elseif k == AstKind.AssignmentStatement then
		if stat.lhs then
			for i, lh in ipairs(stat.lhs) do
				if lh.base  ~= nil then lh.base  = resolve(lh.base,  envScope, envId) end
				if lh.index ~= nil and type(lh.index) == "table" then
					lh.index = resolve(lh.index, envScope, envId)
				end
				-- Convert global AssignmentVariable -> AssignmentIndexing(env, "name")
				if lh.__globalName then
					lh.kind  = AstKind.AssignmentIndexing;
					lh.__globalBlockScope:addReferenceToHigherScope(envScope, envId);
					lh.base  = Ast.VariableExpression(envScope, envId);
					lh.index = Ast.StringExpression(lh.__globalName);
					lh.__globalName = nil;
					lh.__globalBlockScope = nil;
				end
			end
		end
		if stat.rhs then
			for i, v in ipairs(stat.rhs) do
				stat.rhs[i] = resolve(v, envScope, envId);
			end
		end

	elseif k == AstKind.ReturnStatement then
		if stat.args then
			for i, arg in ipairs(stat.args) do
				stat.args[i] = resolve(arg, envScope, envId);
			end
		end

	elseif k == AstKind.IfStatement then
		if stat.condition then
			stat.condition = resolve(stat.condition, envScope, envId);
		end
		if stat.elseifs then
			for _, elif in ipairs(stat.elseifs) do
				if elif.condition then
					elif.condition = resolve(elif.condition, envScope, envId);
				end
			end
		end

	elseif k == AstKind.WhileStatement then
		if stat.condition then
			stat.condition = resolve(stat.condition, envScope, envId);
		end

	elseif k == AstKind.RepeatStatement then
		if stat.condition then
			stat.condition = resolve(stat.condition, envScope, envId);
		end

	elseif k == AstKind.ForStatement then
		if stat.start  then stat.start  = resolve(stat.start,  envScope, envId) end
		if stat.stop   then stat.stop   = resolve(stat.stop,   envScope, envId) end
		if stat.step   then stat.step   = resolve(stat.step,   envScope, envId) end

	elseif k == AstKind.ForInStatement then
		if stat.iterators then
			for i, iter in ipairs(stat.iterators) do
				stat.iterators[i] = resolve(iter, envScope, envId);
			end
		end
	end
end

function StringifyGlobals:apply(ast, pipeline)
	local rootScope = ast.body.scope;

	local globalScope = rootScope;
	while globalScope.parentScope do
		globalScope = globalScope.parentScope;
	end

	local _, getfenvId = globalScope:resolve("getfenv");
	local _, envGlobalId = globalScope:resolve("_ENV");

	-- Single local env variable at root scope so inner functions can close over it
	local envId = rootScope:addVariable();

	if getfenvId then
		rootScope:addReferenceToHigherScope(globalScope, getfenvId);
		table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(
			rootScope,
			{ envId },
			{ Ast.FunctionCallExpression(
				Ast.VariableExpression(globalScope, getfenvId),
				{}
			)}
		));
	elseif envGlobalId then
		table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(
			rootScope,
			{ envId },
			{ Ast.VariableExpression(globalScope, envGlobalId) }
		));
	end

	visitast(ast, nil, function(node, data)
		if node.kind ~= AstKind.Block then return end

		local newStatements = {};

		for _, stat in ipairs(node.statements) do
			local injections = {};

			walkStat(stat, node.scope, self.Treshold, injections);
			resolveStatPlaceholders(stat, rootScope, envId);

			-- Emit strVar locals before the statement for env lookups
			for _, inj in ipairs(injections) do
				table.insert(newStatements, Ast.LocalVariableDeclaration(
					node.scope,
					{ inj.strVar },
					{ Ast.StringExpression(inj.name) }
				));
			end

			table.insert(newStatements, stat);
		end

		node.statements = newStatements;
	end);
end

return StringifyGlobals;