--[[
Title: CodeBlocklySerializer
Author(s): leio
Date: 2018/6/17
Desc: the help functions for reading/writing blockly informaion 
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeBlocklySerializer.lua");
local CodeBlocklySerializer = commonlib.gettable("MyCompany.Aries.Game.Code.CodeBlocklySerializer");
CodeBlocklySerializer.WriteBlocklyMenuToXml("test_blockly_menu.xml");
CodeBlocklySerializer.WriteToBlocklyConfig("test_blockly_config.json");
CodeBlocklySerializer.WriteToBlocklyCode("test_blockly_execution.js");
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/Json.lua");

NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeHelpData.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeHelpWindow.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeHelpItem.lua");

local CodeHelpData = commonlib.gettable("MyCompany.Aries.Game.Code.CodeHelpData");
local CodeHelpWindow = commonlib.gettable("MyCompany.Aries.Game.Code.CodeHelpWindow");
local CodeHelpItem = commonlib.gettable("MyCompany.Aries.Game.Code.CodeHelpItem");

local CodeBlocklySerializer = commonlib.gettable("MyCompany.Aries.Game.Code.CodeBlocklySerializer");

-- create a xml menu
function CodeBlocklySerializer.WriteBlocklyMenuToXml(filename)
	local categories = CodeHelpWindow.GetCategoryButtons()
	local all_cmds = CodeHelpData.GetAllCmds();
	if(not filename or not categories or not all_cmds)then return end
	local s = [[<xml id="toolbox" style="display: none">]];
	local k,v;
	for k,v in ipairs(categories) do
		local c_s = CodeBlocklySerializer.GetCategoryStr(v);
		s = string.format("%s\n%s",s,c_s);
	end
	s = string.format("%s\n</xml>",s);
	local file = ParaIO.open(filename, "w");
	if(file:IsValid()) then
		file:WriteString(s);
		file:close();
	end
end
function CodeBlocklySerializer.GetCategoryStr(category)
	local all_cmds = CodeHelpData.GetAllCmds();
	if(not category or not all_cmds)then return end
	commonlib.echo(category);
	local s = string.format("<category name='%s' colour='%s'>\n",category.text or category.name,category.colour or "#000000");
	local cmd
	for __,cmd in ipairs(all_cmds) do
		if(category.name == cmd.category)then
			s = string.format("%s<block type='%s'></block>\n",s,cmd.type);
		end
	end
	s = string.format("%s</category>",s);
	return s;
end
-- write a json file to config all of blocks
-- how to define-blocks:https://developers.google.com/blockly/guides/create-custom-blocks/define-blocks
function CodeBlocklySerializer.WriteToBlocklyConfig(filename)
	local all_cmds = CodeHelpData.GetAllCmds();
	if(not filename or not all_cmds)then return end

	local categories = CodeHelpWindow.GetCategoryButtons()
	local c_map = {};
	local k,v;
	for k,v in ipairs(categories) do
		local name = v.name;
		c_map[name] = v;
	end
	all_cmds = commonlib.deepcopy(all_cmds)
	for k,v in ipairs(all_cmds) do
		local category = v.category;
		if(not v.colour)then
			local c_node = c_map[category];
			-- set colour
			v.colour = c_node.colour;
		end
	end

	local file = ParaIO.open(filename, "w");
	if(file:IsValid()) then
		file:WriteString(NPL.ToJson(all_cmds,true));
		file:close();
	end
end
-- create a js file for execution
-- generating-code: https://developers.google.com/blockly/guides/create-custom-blocks/generating-code
function CodeBlocklySerializer.WriteToBlocklyCode(filename)
	if(not filename)then return end
	local all_cmds = CodeHelpData.GetAllCmds();
	local s = "";
	local cmd
	for __,cmd in ipairs(all_cmds) do
		local execution_str = CodeBlocklySerializer.GetBlockExecutionStr(cmd)
		if(s == "")then
			s = execution_str;
		else
			s = s .. "\n" .. execution_str;
		end
	end
	local file = ParaIO.open(filename, "w");
	if(file:IsValid()) then
		file:WriteString(s);
		file:close();
	end
end
function CodeBlocklySerializer.GetBlockExecutionStr(cmd)
	local type = cmd.type;
	local body = CodeBlocklySerializer.ArgsToStr(cmd);
	local s = string.format([[
Blockly.Lua['%s'] = function (block) {
  %s
};
	]],type,body)
	return s;
end
--[[
supported filed:
	field_input
	field_number
supported input:
	input_statement
--]]
function CodeBlocklySerializer.ArgsToStr(cmd)
	local type = cmd.type
	local arg0 = cmd.arg0
	local var_lines = nil;
	local arg_lines = nil;
	local k,v;
	for k,v in ipairs(arg0) do
		local var_str = CodeBlocklySerializer.ArgToJsStr_Variable(type,v)
		local arg_str = CodeBlocklySerializer.ArgToJsStr_ArgName(type,v);
		if(k == 1)then
			var_lines = var_str;
			arg_lines = arg_str;
		else
			var_lines = var_lines .. "\n" .. var_str;
			arg_lines = arg_lines .. " + ',' + " .. arg_str;
		end
	end
	local s = string.format([[%s
return '%s(' + %s + ');\n';
]],var_lines,type,arg_lines);
	return s;
end
function CodeBlocklySerializer.ArgToJsStr_Variable(prefix,arg)
	local type = arg.type
	local name = arg.name
	local s;
	if(type == "input_statement")then
		s = string.format([[
var %s_statement = Blockly.Lua.statementToCode(block, '%s') || '';
		]],prefix,name)
	else
		s = string.format([[
var %s_%s_value = block.getFieldValue('%s');
		]],prefix,name,name);
	end
	return s;
end
function CodeBlocklySerializer.ArgToJsStr_ArgName(prefix,arg)
	local type = arg.type
	local name = arg.name
	local s;
	if(type == "input_statement")then
		s = string.format([[
'function()\n' + 
	%s_statement
+ 'end'
		]],prefix)
	else
		s = string.format([[%s_%s_value]],prefix,name);
	end
	return s;
end
