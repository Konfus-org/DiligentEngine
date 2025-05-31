local generatedDir = "./Generated/"

-- Clear generated directory
local function DeleteDirectory(dir)
    if os.host() == "windows" then
        -- /S: Remove all files and subfolders
        -- /Q: Quiet mode (no confirmation)
        os.execute('rmdir /S /Q "' .. dir .. '"')
    else
        -- Unix-like systems (Linux, macOS)
        os.execute('rm -rf "' .. dir .. '"')
    end
end
DeleteDirectory(generatedDir)

-- Local util functions:

local function CompileShaderToStringFile(srcPath, dstPath)
    -- Open source file for reading
    local srcFile = io.open(srcPath, "r")
    if not srcFile then
        error("Could not open source file: " .. srcPath)
    end

    -- Open destination file for writing
    local dstFile = io.open(dstPath, "w")
    if not dstFile then
        srcFile:close()
        error("Could not open destination file: " .. dstPath)
    end

    print("Generating shaders " .. srcPath .. " -> " .. dstPath)

    -- Process each line
    for line in srcFile:lines() do
        local escaped = "\""

        for i = 1, #line do
            local c = line:sub(i, i)
            if c == "'" or c == '"' or c == '\\' then
                escaped = escaped .. "\\"
            end
            escaped = escaped .. c
        end

        escaped = escaped .. "\\n\"\n"
        dstFile:write(escaped)
    end

    -- Close files
    srcFile:close()
    dstFile:close()

    print("Done! \n")
end

local function AddDxCompileShadersCommands()
    local shaders =
    {
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsGammaCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsGammaOddCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsGammaOddXCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsGammaOddYCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsLinearCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsLinearOddCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsLinearOddXCS.hlsl",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/GenerateMipsLinearOddYCS.hlsl",
    }

    local compiledShadersDir = generatedDir .. "GenerateMips/"
    os.mkdir(compiledShadersDir)

    for _, srcShader in ipairs(shaders) do
        local shaderName = path.getbasename(srcShader)
        local compiledShader = path.join(compiledShadersDir, shaderName .. ".h")

        prebuildcommands
        {
            string.format(
                'fxc /T cs_5_0 /E main /Vn g_p%s /Fh "%s" "%s"',
                shaderName,
                compiledShader,
                srcShader
            )
        }
    end
end

local function GetAllFilesInDirRecursively(dir)
    local files = {}

    -- Get files in current directory
    local entries = os.matchfiles(path.join(dir, "*"))

    for _, entry in ipairs(entries) do
        table.insert(files, entry)
    end

    -- Recurse into subdirectories
    local subdirs = os.matchdirs(path.join(dir, "*"))
    for _, subdir in ipairs(subdirs) do
        local subfiles = GetAllFilesInDirRecursively(subdir)
        for _, file in ipairs(subfiles) do
            table.insert(files, file)
        end
    end

    return files
end

local function ConvertShadersToHeaders(shaders, shaderOutputDir, shadersListFile)
        -- Ensure output directory exists
        os.mkdir(shaderOutputDir)

        -- Write the initial shaders list file content
        local shadersListHandle = io.open(shadersListFile, "w")
        shadersListHandle:write("static const MemoryShaderSourceFileInfo g_Shaders[] =\n{\n")
        shadersListHandle:close()

        local shadersIncList = {}

        for _, file in ipairs(shaders) do
            local fileName = path.getname(file)
            local convertedFile = path.join(shaderOutputDir, fileName .. ".h")

            CompileShaderToStringFile(file, convertedFile)

            -- Append to shader list file
            shadersListHandle = io.open(shadersListFile, "a")
            shadersListHandle:write(string.format(
            [[
                {
                    "%s",
                    #include "%s.h"
                },
            ]], fileName, fileName))
            shadersListHandle:close()

            table.insert(shadersIncList, convertedFile)
        end

        -- Close the list
        shadersListHandle = io.open(shadersListFile, "a")
        shadersListHandle:write("\n};\n")
        shadersListHandle:close()
end

-- Project defs:

group("Dependencies/DiligentEngine/Core")

function UseDiligentPrimitives()
    includedirs
    {
        "./DiligentCore/Primitives/interface",
    }
    if project().name ~= "DiligentPrimitives" then
        links { "DiligentPrimitives" }
    end
end

project "DiligentPrimitives"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Primitives/src/**.cpp",
    }
    UseDiligentPrimitives()

function IncludeDiligentPlatforms()
    includedirs
    {
        "./DiligentCore/Platforms/interface",
        "./DiligentCore/Platforms/Basic/interface",
        "./DiligentCore/Platforms/Basic/include"
    }
    UseDiligentPrimitives()
end

function UseDiligentWin32Platform()
    defines { "PLATFORM_WIN32" }
    includedirs { "./DiligentCore/Platforms/Win32/interface" }
    if project().name ~= "DiligentPlatformWin32" then
        links { "DiligentPlatformWin32" }
    end
    IncludeDiligentPlatforms()
end

group("Dependencies/DiligentEngine/Platform")

project "DiligentPlatformWin32"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Platforms/Basic/src/**.cpp",
        "./DiligentCore/Platforms/Win32/src/**.cpp"
    }
    UseDiligentWin32Platform()

function UseDiligentLinuxPlatform()
    defines { "PLATFORM_LINUX" }
    includedirs { "./DiligentCore/Platforms/Linux/interface" }
    if project().name ~= "DiligentPlatformLinux" then
        links { "DiligentPlatformLinux" }
    end
    IncludeDiligentPlatforms()
end

project "DiligentPlatformLinux"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Platforms/Basic/src/**.cpp",
        "./DiligentCore/Platforms/Linux/src/**.cpp"
    }
    UseDiligentLinuxPlatform()

function UseDiligentMacOSPlatform()
    defines { "PLATFORM_MACOS" }
    includedirs { "./DiligentCore/Platforms/Apple/interface" }
    if project().name ~= "DiligentPlatformMacOS" then
        links { "DiligentPlatformMacOS" }
    end
    IncludeDiligentPlatforms()
end

project "DiligentPlatformMacOS"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Platforms/Basic/src/**.cpp",
        "./DiligentCore/Platforms/Apple/src/**.cpp"
    }
    UseDiligentMacOSPlatform()

function UseDiligentPlatforms()
    IncludeDiligentPlatforms()
    filter "system:Windows"
        systemversion "latest"
        defines { "PLATFORM_WIN32" }
        links { "DiligentPlatformWin32" }
        includedirs { "./DiligentCore/Platforms/Win32/interface" }
    filter "system:Linux"
        systemversion "latest"
        defines { "PLATFORM_LINUX" }
        links { "DiligentPlatformLinux" }
        includedirs { "./DiligentCore/Platforms/Linux/interface" }
    filter "system:Macosx"
        systemversion "latest"
        defines { "PLATFORM_MACOS" }
        links { "DiligentPlatformMacOS" }
        includedirs { "./DiligentCore/Platforms/Apple/interface" }
    filter {}
end

group("Dependencies/DiligentEngine/Core")

function UseDiligentCommon()
    includedirs
    {
        "./DiligentCore/Common/include",
        "./DiligentCore/Common/interface"
    }
    if project().name ~= "DiligentCommon" then
        links { "DiligentCommon" }
    end
    UseDiligentPlatforms()
end

project "DiligentCommon"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Common/src/**.cpp"
    }
    UseDiligentCommon()

group("Dependencies/DiligentEngine/Graphics")

function IncludeDiligentGraphics()
    includedirs
    {
        "./DiligentCore/ThirdParty/xxHash",
        "./DiligentCore/ThirdParty/SPIRV-Tools/include",
        "./DiligentCore/ThirdParty/SPIRV-Headers/include",
        "./DiligentCore/ThirdParty/SPIRV-Cross/include",
        "./DiligentCore/ThirdParty/SPIRV-Cross/",
        "./DiligentCore/ThirdParty/glslang/SPIRV",
        "./DiligentCore/ThirdParty/glslang",
        "./DiligentCore/ThirdParty/xxHash",

        "./DiligentCore/Graphics/GraphicsEngine/interface",
        "./DiligentCore/Graphics/GraphicsEngine/include",
        "./DiligentCore/Graphics/GraphicsEngineNextGenBase/include",
        "./DiligentCore/Graphics/GraphicsAccessories/interface",
        "./DiligentCore/Graphics/GraphicsTools/interface",
        "./DiligentCore/Graphics/GraphicsTools/include",
        "./DiligentCore/Graphics/GraphicsTools/interface",
        "./DiligentCore/Graphics/GraphicsTools/include",
        "./DiligentCore/Graphics/Archiver/interface",
        "./DiligentCore/Graphics/Archiver/include",

        generatedDir
    }
    UseDiligentCommon();
end

function UseDiligentDXGraphics()
    defines
    {
        "D3D12_SUPPORTED"
    }
    includedirs
    {
        "./DiligentCore/Graphics/ShaderTools/include",
        "./DiligentCore/ThirdParty/DirectXShaderCompiler",

        "./DiligentCore/Graphics/GraphicsEngineD3DBase/include",
        "./DiligentCore/Graphics/GraphicsEngineD3DBase/interface",

        "./DiligentCore/Graphics/GraphicsEngineD3D12/include",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/interface",
        "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders"
    }
    if project().name ~= "DiligentDXGraphics" then
        links { "DiligentDXGraphics" }
    end
    AddDxCompileShadersCommands()
    IncludeDiligentGraphics()
    UseDiligentWin32Platform()
end

project "DiligentDXGraphics"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Graphics/GraphicsEngine/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsEngineNextGenBase/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsAccessories/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/AsyncPipelineState.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/BufferSuballocator.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/BytecodeCache.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DurationQueryHelper.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DynamicBuffer.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DynamicTextureArray.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DynamicTextureAtlas.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/GraphicsUtilities.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/OffScreenSwapChain.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ReloadablePipelineState.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ReloadableShader.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/RenderStateCacheImpl.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ScopedQueryHelper.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ScreenCapture.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ShaderSourceFactoryUtils.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/TextureUploader.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/VertexPool.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/XXH128Hasher.cpp",

        "./DiligentCore/Graphics/GraphicsEngineD3D12/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsEngineD3DBase/src/**.cpp",

        "./DiligentCore/Graphics/Archiver/src/Archiver_D3D12.cpp",

        "./DiligentCore/Graphics/GraphicsTools/src/GraphicsUtilitiesD3D12.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/TextureUploaderD3D12_Vk.cpp"
    }
    UseDiligentDXGraphics()

function UseDiligentGLGraphics()
    defines
    {
        "GL_SUPPORTED"
    }
    includedirs
    {
        "./DiligentCore/ThirdParty/glew/include",
        "./DiligentCore/Graphics/ShaderTools/include",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/include",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/interface",
    }
    if project().name ~= "DiligentGLGraphics" then
        links { "DiligentGLGraphics" }
    end
    IncludeDiligentGraphics()
    UseDiligentShaders()
end

function UseDiligentShaders()
    includedirs
    {
        "./DiligentCore/Graphics/ShaderTools/include",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/include",
        generatedDir
    }
    if project().name ~= "DiligentShaders" then
        links { "DiligentShaders" }
    end
    IncludeDiligentGraphics()
    filter "system:Windows"
        systemversion "latest"
        defines { "PLATFORM_WIN32", "D3D12_SUPPORTED", "GL_SUPPORTED" }
        links { "DiligentDXGraphics", } -- For now just DX "DiligentGLGraphics", "DiligentVKGraphics" }
    filter "system:Linux"
        systemversion "latest"
        defines { "PLATFORM_LINUX", "GL_SUPPORTED" }
        links { "DiligentGLGraphics", "DiligentVKGraphics" }
    filter "system:Macosx"
        systemversion "latest"
        defines { "PLATFORM_MACOS", "GL_SUPPORTED" }
        links { "DiligentGLGraphics" }
    filter {}
end

project "DiligentShaders"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/src/**.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/GLSLangUtils.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/GLSLParsingTools.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/GLSLUtils.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/HLSLParsingTools.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/HLSLTokenizer.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/HLSLUtils.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/ShaderToolsCommon.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/SPIRVShaderResources.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/SPIRVTools.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/SPIRVUtils.cpp",

        "./Generated/HLSLDefinitions_inc.fxh",
        "./Generated/GLSLDefinitions_inc.h"
    }
    CompileShaderToStringFile("./DiligentCore/Graphics/ShaderTools/include/HLSLDefinitions.fxh", "./Generated/HLSLDefinitions_inc.fxh")
    CompileShaderToStringFile("./DiligentCore/Graphics/HLSL2GLSLConverterLib/include/GLSLDefinitions.h", "./Generated/GLSLDefinitions_inc.h")
    UseDiligentShaders()

function UseDiligentDXShaders()
    includedirs { "./DiligentCore/ThirdParty/DirectXShaderCompiler" }
    if project().name ~= "DiligentDXShaders" then
        links { "DiligentDXShaders" }
    end
    UseDiligentShaders()
    UseDiligentWin32Platform()
end

project "DiligentGLGraphics"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Graphics/GraphicsEngine/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsEngineNextGenBase/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsAccessories/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/AsyncPipelineState.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/BufferSuballocator.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/BytecodeCache.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DurationQueryHelper.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DynamicBuffer.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DynamicTextureArray.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/DynamicTextureAtlas.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/GraphicsUtilities.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/OffScreenSwapChain.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ReloadablePipelineState.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ReloadableShader.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/RenderStateCacheImpl.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ScopedQueryHelper.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ScreenCapture.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/ShaderSourceFactoryUtils.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/TextureUploader.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/VertexPool.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/XXH128Hasher.cpp",

        "./DiligentCore/Graphics/Archiver/src/Archiver_GL.cpp",

        "./DiligentCore/Graphics/GraphicsTools/src/GraphicsUtilitiesGL.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/TextureUploaderGL.cpp",

        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/BufferGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/BufferViewGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/DearchiverGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/DeviceContextGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/DeviceObjectArchiveGL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/DLLMain.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/EngineFactoryOpenGL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/FBOCache.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/FenceGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/FramebufferGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLAdapterSelector.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLObjectWrapper.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLProgram.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLProgramCache.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLTypeConversions.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GraphicsEngineOpenGL.def",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/PipelineResourceSignatureGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/PipelineStateGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/QueryGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/RenderDeviceGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/RenderPassGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/SamplerGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/ShaderResourceBindingGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/ShaderResourceCacheGL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/ShaderResourcesGL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/ShaderVariableManagerGL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/SwapChainGLImpl.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/Texture1DArray_GL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/Texture1D_GL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/Texture2D_GL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/Texture3D_GL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/TextureBaseGL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/TextureCubeArray_GL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/TextureCube_GL.cpp",
        "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/VAOCache.cpp"
    }
    UseDiligentGLGraphics()
    filter "system:Windows"
        systemversion "latest"
        files { "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLContextWindows.cpp" }
    filter "system:Linux"
        systemversion "latest"
        files{ "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLContextMacOS.mm" }
    filter "system:Macosx"
        systemversion "latest"
        files { "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/GLContextMacOS.mm" }
    filter {}

-- function UseDiligentVKGraphics()
--     defines
--     {
--         "VULKAN_SUPPORTED"
--     }
--     includedirs
--     {
--         "./DiligentCore/Graphics/ShaderTools/include",
--         "./DiligentCore/Graphics/GraphicsEngineVulkan/include",
--         "./DiligentCore/Graphics/GraphicsEngineVulkan/interface",
--     }
--     if project().name ~= "DiligentVKGraphics" then
--         links { "DiligentVKGraphics" }
--     end
--     UseDiligentGraphicsBase()
-- end

-- project "DiligentVKGraphics"
--     kind "StaticLib"
--     language "C++"
--     cppdialect "C++17"
--     staticruntime "Off"
--     files
--     {
--         "./DiligentCore/Graphics/GraphicsEngine/src/**.cpp",
--         "./DiligentCore/Graphics/GraphicsEngineNextGenBase/src/**.cpp",
--         "./DiligentCore/Graphics/GraphicsAccessories/src/**.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/AsyncPipelineState.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/BufferSuballocator.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/BytecodeCache.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/DurationQueryHelper.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/DynamicBuffer.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/DynamicTextureArray.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/DynamicTextureAtlas.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/GraphicsUtilities.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/OffScreenSwapChain.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/ReloadablePipelineState.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/ReloadableShader.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/RenderStateCacheImpl.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/ScopedQueryHelper.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/ScreenCapture.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/ShaderSourceFactoryUtils.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/TextureUploader.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/VertexPool.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/XXH128Hasher.cpp",

--         "./DiligentCore/Graphics/GraphicsEngineVulkan/src/**.cpp",

--         "./DiligentCore/Graphics/Archiver/src/Archiver_Vk.cpp",

--         "./DiligentCore/Graphics/GraphicsTools/src/GraphicsUtilitiesVk.cpp",
--         "./DiligentCore/Graphics/GraphicsTools/src/TextureUploaderD3D12_Vk.cpp"
--     }
--     UseDiligentVKGraphics()

project "DiligentDXShaders"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentCore/Graphics/ShaderTools/src/DXCompiler.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/DXCompilerLibrary.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/DXCompilerLibraryWin32.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/DXBCUtils.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/DXILUtilsStub.cpp"
    }
    UseDiligentDXShaders()

function IncludeDiligentImGui()
    includedirs
    {
        "./DiligentTools/ThirdParty/imgui",
        "./DiligentTools/ThirdParty/imgui/backends",
        "./DiligentTools/Imgui/interface"
    }
    IncludeDiligentGraphics()
end

function UseDiligentImGuiWin32()
    if project().name ~= "DiligentImGuiWin32" then
        links { "DiligentImGuiWin32" }
    end
    IncludeDiligentImGui()
    UseDiligentWin32Platform()
end

group("Dependencies/DiligentEngine/ImGui")

project "DiligentImGuiWin32"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentTools/ImGui/src/ImGuiDiligentRenderer.cpp",
        "./DiligentTools/ImGui/src/ImGuiImplDiligent.cpp",
        "./DiligentTools/ImGui/src/ImGuiUtils.cpp",
        "./DiligentTools/ImGui/src/ImGuiImplWin32.cpp"
    }
    UseDiligentImGuiWin32()

function UseDiligentImGuiLinux()
    links { "DiligentImGuiLinux" }
    if project().name ~= "DiligentImGuiLinux" then
        links { "DiligentImGuiLinux" }
    end
    IncludeDiligentImGui()
    UseDiligentLinuxPlatform()
end

project "DiligentImGuiLinux"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentTools/ImGui/src/ImGuiDiligentRenderer.cpp",
        "./DiligentTools/ImGui/src/ImGuiImplDiligent.cpp",
        "./DiligentTools/ImGui/src/ImGuiUtils.cpp",
        "./DiligentTools/ImGui/src/ImGuiImplWin32.cpp"
    }
    UseDiligentImGuiLinux()

function UseDiligentImGuiMacOS()
    if project().name ~= "DiligentImGuiMacOS" then
        links { "DiligentImGuiMacOS" }
    end
    IncludeDiligentImGui()
    UseDiligentMacOSPlatform()
end

project "DiligentImGuiMacOS"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentTools/ImGui/src/ImGuiDiligentRenderer.cpp",
        "./DiligentTools/ImGui/src/ImGuiImplDiligent.cpp",
        "./DiligentTools/ImGui/src/ImGuiUtils.cpp",
        "./DiligentTools/ImGui/src/ImGuiImplMacOS.mm"
    }
    UseDiligentImGuiMacOS()

function UseDiligentImGui()
    IncludeDiligentImGui()
    filter "system:Windows"
        systemversion "latest"
        defines { "PLATFORM_WIN32", "D3D12_SUPPORTED", "GL_SUPPORTED" }
        links { "DiligentDXGraphics", "DiligentGLGraphics", "DiligentImGuiWin32" }
    filter "system:Linux"
        systemversion "latest"
        defines { "PLATFORM_LINUX", "GL_SUPPORTED", "DiligentImGuiLinux" }
        links { "DiligentGLGraphics" }
    filter "system:Macosx"
        systemversion "latest"
        defines { "PLATFORM_MACOS", "GL_SUPPORTED" }
        links { "DiligentGLGraphics", "DiligentVKGraphics", "DiligentImGuiMacOS" }
    filter {}
end

function UseDiligentTools()
    includedirs
    {
        "./DiligentTools/ThirdParty/json/single_include/nlohmann",
        "./DiligentTools/ThirdParty/libtiff",
        "./DiligentTools/ThirdParty/libpng",

        "./DiligentTools/AssetLoader/interface",
        "./DiligentTools/TextureLoader/interface",
        "./DiligentTools/TextureLoader/include",

        generatedDir
    }
    if project().name ~= "DiligentTools" then
        links { "DiligentTools" }
    end
    UseDiligentShaders()
end

group("Dependencies/DiligentEngine")

project "DiligentTools"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"

    os.mkdir(generatedDir)
    os.copyfile("DiligentTools/ThirdParty/libpng/scripts/pnglibconf.h.prebuilt", generatedDir .. "pnglibconf.h")

    files
    {
        "./DiligentTools/AssetLoader/src/**.cpp",
        "./DiligentTools/TextureLoader/src/**.cpp"
    }
    UseDiligentTools()

function UseDiligentFX()
    includedirs
    {
        "./DiligentFX/",
        "./DiligentFX/Utilities",
        "./DiligentFX/Utilities/interface",
        "./DiligentFX/Components/interface",
        "./DiligentFX/PBR/interface",
        "./DiligentFX/PostProcess/**/interface",
        "./DiligentFX/Shaders/**/public",
        "./DiligentFX/Shaders/",
        generatedDir
    }
    if project().name ~= "DiligentFX" then
        links { "DiligentFX" }
    end
    UseDiligentTools()
    UseDiligentImGui()
end

project "DiligentFX"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"
    files
    {
        "./DiligentFX/Utilities/src/**.cpp",
        "./DiligentFX/Components/src/**.cpp",
        "./DiligentFX/PBR/src/**.cpp",
        "./DiligentFX/PostProcess/Bloom/src/**.cpp",
        "./DiligentFX/PostProcess/DepthOfField/src/**.cpp",
        "./DiligentFX/PostProcess/EpipolarLightScattering/src/**.cpp",
        "./DiligentFX/PostProcess/ScreenSpaceAmbientOcclusion/src/**.cpp",
        "./DiligentFX/PostProcess/SuperResolution/src/**.cpp",
        "./DiligentFX/PostProcess/TemporalAntiAliasing/src/**.cpp",
        "./DiligentFX/PostProcess/Common/src/PostFXContext.cpp",
        "./DiligentFX/PostProcess/Common/src/PostFXRenderTechnique.cpp",
    }
    UseDiligentFX()
    local shaders = GetAllFilesInDirRecursively("./DiligentFX/Shaders");
    ConvertShadersToHeaders(shaders, generatedDir,  generatedDir .. "shaders_list.h")
group("")