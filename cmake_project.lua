--
-- Copyright (c) 2019 Aldo Nicolas Bruno
--
-- Based on codelite premake plugin:--
-- Name:        cmake/cmake_project.lua
-- Purpose:     Generate a cmake C/C++ project file.
-- Author:      Ryan Pusztai
-- Modified by: Andrea Zanellato
--              Manu Evans
--              Tom van Dijck
-- Created:     2013/05/06
-- Copyright:   (c) 2008-2016 Jason Perkins and the Premake project
--

	local p = premake
	local tree = p.tree
	local project = p.project
	local config = p.config
	local cmake = p.modules.cmake

	cmake.project = {}
	local m = cmake.project


	function cmake.getLinks(cfg)
		-- System libraries are undecorated, add the required extension
		return config.getlinks(cfg, "system", "fullpath")
	end

	function cmake.getSiblingLinks(cfg)
		-- If we need sibling projects to be listed explicitly, add them on
		return config.getlinks(cfg, "siblings", "fullpath")
	end


	m.elements = {}

	m.ctools = {
		gcc = "gnu gcc",
		clang = "clang",
		msc = "Visual C++",
	}
	m.cxxtools = {
		gcc = "gnu g++",
		clang = "clang++",
		msc = "Visual C++",
	}

	function m.getcompilername(cfg)
		local tool = _OPTIONS.cc or cfg.toolset or p.CLANG

		local toolset = p.tools[tool]
		if not toolset then
			error("Invalid toolset '" + (_OPTIONS.cc or cfg.toolset) + "'")
		end

		if p.languages.isc(cfg.language) then
			return m.ctools[tool]
		elseif p.languages.iscpp(cfg.language) then
			return m.cxxtools[tool]
		end
	end

	function m.getcompiler(cfg)
		local toolset = p.tools[_OPTIONS.cc or cfg.toolset or p.CLANG]
		if not toolset then
			error("Invalid toolset '" + (_OPTIONS.cc or cfg.toolset) + "'")
		end
		return toolset
	end

	local function configuration_iscustombuild(cfg)

		return cfg and (cfg.kind == p.MAKEFILE) and (#cfg.buildcommands > 0)
	end

	local function configuration_isfilelist(cfg)

		return cfg and (cfg.buildaction == "None") and not configuration_iscustombuild(cfg)
	end

	local function configuration_needresoptions(cfg)

		return cfg and config.findfile(cfg, ".rc") and not configuration_iscustombuild(cfg)
	end


	m.internalTypeMap = {
		ConsoleApp = "Console",
		WindowedApp = "Console",
		Makefile = "",
		SharedLib = "Library",
		StaticLib = "Library"
	}

	function m.header(prj)
		--_p('<?xml version="1.0" encoding="UTF-8"?>')
		--local type = m.internalTypeMap[prj.kind] or ""
		--_x('<cmake_Project Name="%s" InternalType="%s">', prj.name, type)
		--p.w("project ('%s_%s' C CXX)", prj.workspace.name, prj.name)
	end

	function m.plugins(prj)
--		_p(1, '<Plugins>')
			-- <Plugin Name="CMakePlugin">
			-- <Plugin Name="qmake">
--		_p(1, '</Plugins>')

		--_p(1, '<Plugins/>')
	end

	function m.description(prj)
		--_p(1, '<Description/>')

		-- TODO: ...
	end

	-- Helper to get path from cmake-bins to a file
	function m.getpath(prj, relpath)
		-- Get project location relative to workspace
		local prjrel = path.getrelative(prj.workspace.location, prj.location)
		-- Combine: ../<project_dir>/<relpath>
		if prjrel == "." then
			return "../" .. relpath
		else
			return "../" .. prjrel .. "/" .. relpath
		end
	end

	-- Helper to check if a file is a valid source file for cmake
	local function is_source_file(filepath)
		local ext = path.getextension(filepath):lower()
		local valid_exts = {
			".c", ".cc", ".cpp", ".cxx", ".c++", ".m", ".mm",  -- source files
			".h", ".hh", ".hpp", ".hxx", ".h++", ".inl",       -- headers
			".rc",                                              -- resource files
		}
		for _, valid in ipairs(valid_exts) do
			if ext == valid then
				return true
			end
		end
		return false
	end

	function m.files(prj)
		local tr = project.getsourcetree(prj)

		-- Determine the cmake command based on project kind
		local cmake_cmd
		if prj.kind == "StaticLib" then
			cmake_cmd = "add_library(%s STATIC"
		elseif prj.kind == "SharedLib" then
			cmake_cmd = "add_library(%s SHARED"
		elseif prj.kind == "WindowedApp" then
			-- WIN32 flag tells cmake to use WinMain instead of main
			cmake_cmd = "add_executable(%s WIN32"
		else
			-- ConsoleApp
			cmake_cmd = "add_executable(%s"
		end

		p.push(cmake_cmd, prj.name)

		tree.traverse(tr, {
			-- folders are handled at the internal nodes
			onbranchenter = function(node, depth)
				--_p(depth, '<VirtualDirectory Name="%s">', node.name)
				--p.w('# Directory: %s', node.name)
			end,
			onbranchexit = function(node, depth)
				--_p(depth, '</VirtualDirectory>')
			end,
			-- source files are handled at the leaves
			onleaf = function(node, depth)
				-- Skip non-source files (like .natvis, .txt, etc.)
				if not is_source_file(node.relpath) then
					return
				end

				local excludesFromBuild = {}
				for cfg in project.eachconfig(prj) do
					local cfgname = cmake.cfgname(cfg)
					local fcfg = p.fileconfig.getconfig(node, cfg)
					if not fcfg or fcfg.flags.ExcludeFromBuild then
						table.insert(excludesFromBuild, cfgname)
					end
				end

				if #excludesFromBuild > 0 then
					p.w("# file excluded: %s", node.relpath)
				else
					local filepath = m.getpath(prj, node.relpath)
					p.w('"${CMAKE_CURRENT_SOURCE_DIR}/%s"', filepath)
				end
			end,
		}, true)
		p.pop(")")

		local function ends_with(str, ending)
		   return ending == "" or str:sub(-#ending) == ending
		end
		tree.traverse(tr, {
			onbranchenter = function(node, depth)
				--p.w('# Directory: %s', node.name)
			end,
			onbranchexit = function(node, depth)
				--_p(depth, '</VirtualDirectory>')
			end,
			onleaf = function(node, depth)
				if not is_source_file(node.relpath) then
					return
				end
				if ends_with(node.relpath,".h") or ends_with(node.relpath,".hpp") or ends_with(node.relpath,".inl") then
					local filepath = m.getpath(prj, node.relpath)
					p.w('set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/%s" PROPERTIES HEADER_FILE_ONLY TRUE)', filepath)
				end
			end,
		}, true)

		--set_source_files_properties ("../../UnRAR/headers5.hpp" PROPERTIES HEADER_FILE_ONLY TRUE)


		p.push("set_target_properties (%s PROPERTIES",prj.name)
		p.w('OUTPUT_NAME "%s"',prj.name)
	    --p.w('CXX_STANDARD 17')
	    --p.w('CXX_EXTENSIONS OFF')
	    p.pop(')')
	end

	function m.dependencies(prj)

		-- TODO: dependencies don't emit a line for each config if there aren't any...

--		_p(1, '<Dependencies/>')

		-- local dependencies = project.getdependencies(prj)
		-- for cfg in project.eachconfig(prj) do
		-- 	cfgname = cmake.cfgname(cfg)
		-- 	if #dependencies > 0 then
		-- 		_p(1, '<Dependencies Name="%s">', cfgname)
		-- 			for _, dependency in ipairs(dependencies) do
		-- 				_p(2, '<Project Name="%s"/>', dependency.name)
		-- 			end
		-- 		_p(1, '</Dependencies>')
		-- 	else
		-- 		_p(1, '<Dependencies Name="%s"/>', cfgname)
		-- 	end
		-- end
	end


	function m.global_compiler(prj)
		-- _p(3, '<Compiler Options="" C_Options="" Assembler="">')
		-- _p(4, '<IncludePath Value="."/>')
		-- _p(3, '</Compiler>')
	end

	function m.global_linker(prj)
		-- _p(3, '<Linker Options="">')
		-- _p(4, '<LibraryPath Value="."/>')
		-- _p(3, '</Linker>')
	end

	function m.global_resourceCompiler(prj)
		-- _p(3, '<ResourceCompiler Options=""/>')
	end

	m.elements.globalSettings = function(prj)
		return {
			m.global_compiler,
			m.global_linker,
			m.global_resourceCompiler,
		}
	end

	local outputs_cache = {}

	-- Helper to clean flags: remove outer quotes and trailing spaces
	local function cleanflag(flag)
		if flag == nil then return "" end
		local s = flag
		-- Remove leading/trailing whitespace
		s = s:gsub("^%s+", ""):gsub("%s+$", "")
		-- Remove surrounding quotes
		s = s:gsub('^"(.*)"$', '%1')
		s = s:gsub("^'(.*)'$", '%1')
		return s
	end

	-- Helper to check if a flag is GCC-specific and should be skipped for cmake
	local function is_gcc_specific_flag(flag)
		-- Skip GCC-specific flags that cmake handles differently
		if flag:match("^-m32") or flag:match("^-m64") then return true end
		if flag:match("^-std=") then return true end  -- cmake uses CMAKE_CXX_STANDARD
		if flag:match("^-g$") or flag:match("^-g[0-3]$") then return true end  -- debug info
		if flag:match("^-O[0-3s]$") then return true end  -- optimization (cmake handles via build type)
		if flag:match("^-W") then return true end  -- warnings (can be platform specific)
		if flag:match("^-f") then return true end  -- GCC -f flags
		if flag:match("^-I") then return true end  -- handled by include_directories
		return false
	end

	local function outputof_table(tbl)
		local t = {}
		for _,x in ipairs(tbl) do
			local clean = cleanflag(x)
			if clean ~= "" then
				table.insert(t, clean)
			end
		end
		return t
	end

	function m.compiler(prj,cfg)
		if configuration_iscustombuild(cfg) or configuration_isfilelist(cfg) then
			--_p(3, '<Compiler Required="no"/>')
			return
		end

		print("compiler for cfg " .. cfg.name)

		-- Only use build options from config, skip toolset flags (they're platform-specific)
		local buildopts = outputof_table(cfg.buildoptions or {})

		-- Filter to only keep MSVC-compatible flags (starting with /)
		local msvc_flags = {}
		for _, f in ipairs(buildopts) do
			if f:match("^/") then
				table.insert(msvc_flags, f)
			end
		end

		if #msvc_flags > 0 then
			p.w('target_compile_options(%s PRIVATE %s)', prj.name, table.concat(msvc_flags, " "))
		end

		p.push('include_directories(')
		for _, includedir in ipairs(cfg.includedirs) do
			-- Check if path is absolute (outside project tree)
			if path.isabsolute(includedir) then
				-- Use absolute path directly (e.g., Vulkan SDK path)
				p.w('"%s"', includedir)
			else
				-- Get path relative to project, then compute from cmake-bins
				local relpath = project.getrelative(cfg.project, includedir)
				local fullpath = m.getpath(prj, relpath)
				p.w('"${CMAKE_CURRENT_SOURCE_DIR}/%s"', fullpath)
			end
		end
		p.pop(')')

		if #cfg.defines > 0 then
			p.push('target_compile_definitions(%s PUBLIC', prj.name)
			for _, define in ipairs(cfg.defines) do
				p.w('%s', p.esc(define):gsub(' ', '\\ '))
			end
			p.pop(')')
		end
	end

	function m.linker(prj,cfg)
		if configuration_iscustombuild(cfg) or configuration_isfilelist(cfg) then
			--_p(3, '<Linker Required="no"/>')
			return
		end

		local toolset = m.getcompiler(cfg)

		-- Get links directly from config for cleaner output
		local libs = {}

		-- Add sibling project dependencies
		local siblings = config.getlinks(cfg, "siblings", "object")
		for _, sibling in ipairs(siblings) do
			table.insert(libs, sibling.project.name)
		end

		-- Add system libraries from links
		for _, link in ipairs(cfg.links) do
			-- Skip sibling projects (already added)
			local isSibling = false
			for _, sib in ipairs(siblings) do
				if sib.project.name == link then
					isSibling = true
					break
				end
			end
			if not isSibling then
				-- Clean up library name
				local libname = link
				-- Remove -l prefix if present
				libname = libname:gsub("^-l", "")
				-- Remove .lib/.a extension if present
				libname = libname:gsub("%.lib$", ""):gsub("%.a$", "")
				table.insert(libs, libname)
			end
		end

		if #libs > 0 then
			p.push('target_link_libraries(%s PUBLIC', prj.name)
			for _, lib in ipairs(libs) do
				p.w('%s', lib)
			end
			p.pop(')')
		end

		-- Convert libdirs to cmake paths
		if #cfg.libdirs > 0 then
			p.push('target_link_directories(%s PUBLIC', prj.name)
			for _, libdir in ipairs(cfg.libdirs) do
				-- Check if path is absolute (outside project tree)
				if path.isabsolute(libdir) then
					-- Use absolute path directly (e.g., Vulkan SDK path)
					p.w('"%s"', libdir)
				else
					local relpath = project.getrelative(cfg.project, libdir)
					local fullpath = m.getpath(prj, relpath)
					p.w('"${CMAKE_CURRENT_SOURCE_DIR}/%s"', fullpath)
				end
			end
			p.pop(')')
		end
	end

	function m.resourceCompiler(prj,cfg)
		if not configuration_needresoptions(cfg) then
			---_p(3, '<ResourceCompiler Options="" Required="no"/>')
			return
		end

		local toolset = m.getcompiler(cfg)
		local defines = table.implode(toolset.getdefines(table.join(cfg.defines, cfg.resdefines)), "", ";", "")
		local options = table.concat(cfg.resoptions, ";")

		--_x(3, '<ResourceCompiler Options="%s%s" Required="yes">', defines, options)
		--for _, includepath in ipairs(table.join(cfg.includedirs, cfg.resincludedirs)) do
			--_x(4, '<IncludePath Value="%s"/>', project.getrelative(cfg.project, includepath))
		--end
		--_p(3, '</ResourceCompiler>')
	end

	function m.general(prj,cfg)
		if configuration_isfilelist(cfg) then
			---_p(3, '<General IntermediateDirectory="." WorkingDirectory="." PauseExecWhenProcTerminates="no"/>')
			return
		end

		local prj = cfg.project

		local isExe = prj.kind == "WindowedApp" or prj.kind == "ConsoleApp"
		local targetpath = project.getrelative(prj, cfg.buildtarget.directory)
		local objdir     = project.getrelative(prj, cfg.objdir)
		local targetname = project.getrelative(prj, cfg.buildtarget.abspath)
		local workingdir = cfg.debugdir or prj.location
		local command    = iif(isExe, path.getrelative(workingdir, cfg.buildtarget.abspath), "")
		local cmdargs    = iif(isExe, table.concat(cfg.debugargs, " "), "") -- TODO: should this be debugargs instead?
		local useseparatedebugargs = "no"
		local debugargs  = ""
		local workingdir = iif(isExe, project.getrelative(prj, cfg.debugdir), "")
		local pauseexec  = iif(prj.kind == "ConsoleApp", "yes", "no")
		local isguiprogram = iif(prj.kind == "WindowedApp", "yes", "no")
		local isenabled  = iif(cfg.flags.ExcludeFromBuild, "no", "yes")
		local ldPath = ''

		for _, libdir in ipairs(cfg.libdirs) do
			ldPath = ldPath .. ":" .. project.getrelative(cfg.project, libdir)
		end

		-- if ldPath == nil or ldPath == '' then
		-- 	_x(3, '<General OutputFile="%s" IntermediateDirectory="%s" Command="%s" CommandArguments="%s" UseSeparateDebugArgs="%s" DebugArguments="%s" WorkingDirectory="%s" PauseExecWhenProcTerminates="%s" IsGUIProgram="%s" IsEnabled="%s"/>',
		-- 		targetname, objdir, command, cmdargs, useseparatedebugargs, debugargs, workingdir, pauseexec, isguiprogram, isenabled)
		-- else
		-- 	ldPath = string.sub(ldPath, 2)
		-- 	_x(3, '<General OutputFile="%s" IntermediateDirectory="%s" Command="LD_LIBRARY_PATH=%s %s" CommandArguments="%s" UseSeparateDebugArgs="%s" DebugArguments="%s" WorkingDirectory="%s" PauseExecWhenProcTerminates="%s" IsGUIProgram="%s" IsEnabled="%s"/>',
 	-- 			targetname, objdir, ldPath, command, cmdargs, useseparatedebugargs, debugargs, workingdir, pauseexec, isguiprogram, isenabled)
		-- end
	end

	function m.environment(prj,cfg)
		local envs = table.concat(cfg.debugenvs, "\n")

		-- _p(3, '<Environment EnvVarSetName="&lt;Use Defaults&gt;" DbgSetName="&lt;Use Defaults&gt;">')
		-- _p(4, '<![CDATA[%s]]>', envs)
		-- _p(3, '</Environment>')
	end

	function m.debugger(prj,cfg)

		-- _p(3, '<Debugger IsRemote="%s" RemoteHostName="%s" RemoteHostPort="%s" DebuggerPath="" IsExtended="%s">', iif(cfg.debugremotehost, "yes", "no"), cfg.debugremotehost or "", iif(cfg.debugport, tostring(cfg.debugport), ""), iif(cfg.debugextendedprotocol, "yes", "no"))
		-- if #cfg.debugsearchpaths > 0 then
		-- 	p.escaper(cmake.escElementText)
		-- 	_p(4, '<DebuggerSearchPaths>%s</DebuggerSearchPaths>', table.concat(p.esc(project.getrelative(cfg.project, cfg.debugsearchpaths)), "\n"))
		-- 	p.escaper(cmake.esc)
		-- else
		-- 	_p(4, '<DebuggerSearchPaths/>')
		-- end
		-- if #cfg.debugconnectcommands > 0 then
		-- 	p.escaper(cmake.escElementText)
		-- 	_p(4, '<PostConnectCommands>%s</PostConnectCommands>', table.concat(p.esc(cfg.debugconnectcommands), "\n"))
		-- 	p.escaper(cmake.esc)
		-- else
		-- 	_p(4, '<PostConnectCommands/>')
		-- end
		-- if #cfg.debugstartupcommands > 0 then
		-- 	p.escaper(cmake.escElementText)
		-- 	_p(4, '<StartupCommands>%s</StartupCommands>', table.concat(p.esc(cfg.debugstartupcommands), "\n"))
		-- 	p.escaper(cmake.esc)
		-- else
		-- 	_p(4, '<StartupCommands/>')
		-- end
		-- _p(3, '</Debugger>')
	end

	function m.preBuild(prj,cfg)
		-- if #cfg.prebuildcommands > 0 then
		-- 	_p(3, '<PreBuild>')
		-- 	local commands = os.translateCommandsAndPaths(cfg.prebuildcommands, cfg.project.basedir, cfg.project.location)
		-- 	p.escaper(cmake.escElementText)
		-- 	for _, command in ipairs(commands) do
		-- 		_x(4, '<Command Enabled="yes">%s</Command>', command)
		-- 	end
		-- 	p.escaper(cmake.esc)
		-- 	_p(3, '</PreBuild>')
		-- end
	end

	function m.postBuild(prj,cfg)
		-- if #cfg.postbuildcommands > 0 then
		-- 	_p(3, '<PostBuild>')
		-- 	local commands = os.translateCommandsAndPaths(cfg.postbuildcommands, cfg.project.basedir, cfg.project.location)
		-- 	p.escaper(cmake.escElementText)
		-- 	for _, command in ipairs(commands) do
		-- 		_x(4, '<Command Enabled="yes">%s</Command>', command)
		-- 	end
		-- 	p.escaper(cmake.esc)
		-- 	_p(3, '</PostBuild>')
		-- end
	end

	function m.customBuild(prj,cfg)
		-- if not configuration_iscustombuild(cfg) then
		-- 	_p(3, '<CustomBuild Enabled="no"/>')
		-- 	return
		-- end

		-- local build   = table.implode(cfg.buildcommands,"","","")
		-- local clean   = table.implode(cfg.cleancommands,"","","")
		-- local rebuild = table.implode(cfg.rebuildcommands,"","","")

		-- _p(3, '<CustomBuild Enabled="yes">')
		-- _x(4, '<BuildCommand>%s</BuildCommand>', build)
		-- _x(4, '<CleanCommand>%s</CleanCommand>', clean)
		-- _x(4, '<RebuildCommand>%s</RebuildCommand>', rebuild)
		-- _p(4, '<PreprocessFileCommand></PreprocessFileCommand>')
		-- _p(4, '<SingleFileCommand></SingleFileCommand>')
		-- _p(4, '<MakefileGenerationCommand></MakefileGenerationCommand>')
		-- _p(4, '<ThirdPartyToolName></ThirdPartyToolName>')
		-- _p(4, '<WorkingDirectory></WorkingDirectory>')
		-- _p(3, '</CustomBuild>')
	end

	function m.additionalRules(prj,cfg)
		-- if configuration_iscustombuild(cfg) then
		-- 	_p(3, '<AdditionalRules/>')
		-- 	return
		-- end

		-- _p(3, '<AdditionalRules>')
		-- _p(4, '<CustomPostBuild/>')
		-- _p(4, '<CustomPreBuild/>')
		-- _p(3, '</AdditionalRules>')
	end

	function m.isCpp11(cfg)
		return (cfg.cppdialect == 'gnu++11') or (cfg.cppdialect == 'C++11') or (cfg.cppdialect == 'gnu++0x') or (cfg.cppdialect == 'C++0x')
	end

	function m.isCpp14(cfg)
		return (cfg.cppdialect == 'gnu++14') or (cfg.cppdialect == 'C++14') or (cfg.cppdialect == 'gnu++1y') or (cfg.cppdialect == 'C++1y')
	end

	function m.completion(prj,cfg)
		-- _p(3, '<Completion EnableCpp11="%s" EnableCpp14="%s">',
		-- 	iif(m.isCpp11(cfg), "yes", "no"),
		-- 	iif(m.isCpp14(cfg), "yes", "no")
		-- )
		-- _p(4, '<ClangCmpFlagsC/>')
		-- _p(4, '<ClangCmpFlags/>')
		-- _p(4, '<ClangPP/>') -- TODO: we might want to set special code completion macros...?
		-- _p(4, '<SearchPaths/>') -- TODO: search paths for code completion?
		-- _p(3, '</Completion>')
	end

	m.elements.settings = function(cfg)
		return {
			m.compiler,
			m.linker,
			m.resourceCompiler,
			m.general,
			m.environment,
			m.debugger,
			m.preBuild,
			m.postBuild,
			m.customBuild,
			m.additionalRules,
			m.completion,
		}
	end

	m.types =
	{
		ConsoleApp  = "Executable",
		Makefile    = "",
		SharedLib   = "Dynamic Library",
		StaticLib   = "Static Library",
		WindowedApp = "Executable",
		Utility     = "",
	}

	m.debuggers =
	{
		Default = "GNU gdb debugger",
		GDB = "GNU gdb debugger",
		LLDB = "LLDB Debugger",
	}

	function m.settings(prj)
		--_p(1, '<Settings Type="%s">', m.types[prj.kind] or "")

		--_p(2, '<GlobalSettings>')
		--p.callArray(m.elements.globalSettings, prj)
		--_p(2, '</GlobalSettings>')

		p.w("IF(NOT CMAKE_BUILD_TYPE)")
		p.w("SET(CMAKE_BUILD_TYPE Release")
		p.w("    CACHE STRING \"Choose the type of build : None Debug Release RelWithDebInfo MinSizeRel.\"")
		p.w("    FORCE)")
		p.w("ENDIF(NOT CMAKE_BUILD_TYPE)")
		p.w('message("* Current build type is : ${CMAKE_BUILD_TYPE}")')

		for cfg in project.eachconfig(prj) do
			local cfgname = cfg.buildcfg
			local compiler = m.getcompilername(cfg)
			local debugger = m.debuggers[cfg.debugger] or m.debuggers.Default
			local type = m.types[cfg.kind]
			print("settings for " .. prj.name .. " " .. cfgname)

			p.w('if(CMAKE_BUILD_TYPE STREQUAL "%s")', cfgname)
			p.callArray(m.elements.settings, prj, cfg)
			p.w('endif()')
		end

		--_p(1, '</Settings>')
	end


	m.elements.project = function(prj)
		return {
			m.header,
			m.plugins,
			m.description,
			m.files,
			m.dependencies,
			m.settings,
		}
	end

--
-- Project: Generate the cmake project file.
--
	function m.generate(prj)
		p.utf8()

		p.callArray(m.elements.project, prj)

		--_p('</cmake_Project>')
	end
