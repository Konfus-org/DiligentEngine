function CommonConfig()
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "Off"

    flags { "MultiProcessorCompile" }

    if OutputIntermediateDir == nil or OutputTargetDir == nil then
        targetdir ("Build/bin/%{prj.name}/")
        objdir    ("Build/obj/%{prj.name}/")

    else
        targetdir ("../../" .. OutputTargetDir .. "")
        objdir    ("../../" .. OutputIntermediateDir .. "")
    end

    filter "configurations:Debug"
        defines { "_DEBUG" }
        runtime "Debug"
        buildoptions { "/MDd" }
        symbols "On"

    filter "configurations:Optimized"
        runtime "Release"
        buildoptions { "/MDd" }
        optimize "On"

    filter "configurations:Release"
        runtime "Release"
        optimize "On"
        buildoptions { "/MD" }
        symbols "Off"
end

project "DiligentCore"
    CommonConfig()
    includedirs
    {
        "./DiligentCore/Common/include",
        "./DiligentCore/Common/interface",
        "./DiligentCore/Primitives/interface"
    }
    files
    {
        "./DiligentCore/Common/src/**.cpp",
        "./DiligentCore/Primitives/src/**.cpp"
    }

project "DiligentPlatforms"
    CommonConfig()
    links { "DiligentCommon" }
    files
    {
        "./DiligentCore/Platforms/Basic/src/**.cpp"
    }
    filter "system:windows"
        systemversion "latest"
        defines { "PLATFORM_WIN32" }
        includedirs
        {
            "./DiligentCore/Common/include",
            "./DiligentCore/Common/interface",
            "./DiligentCore/Primitives/interface",
            "./DiligentCore/Platforms/interface",
            "./DiligentCore/Platforms/Basic/interface",
            "./DiligentCore/Platforms/Basic/include",
            "./DiligentCore/Platforms/Win32/interface"
        }
        files { "./DiligentCore/Platforms/Win32/src/**.cpp" }
    filter "system:linux"
        systemversion "latest"
        defines { "PLATFORM_LINUX" }
        includedirs
        {
            "./DiligentCore/Common/include",
            "./DiligentCore/Common/interface",
            "./DiligentCore/Primitives/interface",
            "./DiligentCore/Platforms/interface",
            "./DiligentCore/Platforms/Basic/interface",
            "./DiligentCore/Platforms/Basic/include",
            "./DiligentCore/Platforms/Linux/interface"
        }
        files { "./DiligentCore/Platforms/Linux/src/**.cpp" }
    filter "system:macosx"
        systemversion "latest"
        defines { "PLATFORM_MACOS" }
        includedirs
        {
            "./DiligentCore/Common/include",
            "./DiligentCore/Common/interface",
            "./DiligentCore/Primitives/interface",
            "./DiligentCore/Platforms/interface",
            "./DiligentCore/Platforms/Basic/interface",
            "./DiligentCore/Platforms/Basic/include",
            "./DiligentCore/Platforms/Apple/interface"
        }
        files { "./DiligentCore/Platforms/Apple/src/**.cpp" }

project "DiligentHLSL2GLSLConverter"
    CommonConfig()
    pchheader "./DiligentCore/Graphics/HLSL2GLSLConverterLib/include/pch.h"
    links { "DiligentCommon", "DiligentPlatforms" }
    includedirs
    {
        "./DiligentCore/Common/include",
        "./DiligentCore/Common/interface",
        "./DiligentCore/Primitives/interface",
        "./DiligentCore/Platforms/interface",
        "./DiligentCore/Platforms/Basic/interface",
        "./DiligentCore/Platforms/Basic/include",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/include"
    }
    files
    {
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/**.cpp"
    }

project "DiligentGraphics"
    CommonConfig()
    links { "DiligentCommon", "DiligentPlatforms" }
    includedirs
    {
        "./DiligentCore/Common/interface",
        "./DiligentCore/Primitives/interface",
        "./DiligentCore/Platforms/interface",
        "./DiligentCore/Platforms/Basic/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/GraphicsEngine/interface",
        "./DiligentCore/Graphics/GraphicsEngineNextGenBase/include",
        "./DiligentCore/Graphics/GraphicsAccessories/interface",
        "./DiligentCore/Graphics/ShaderTools/interface",
        "./DiligentCore/Graphics/ShaderTools/include",
        "./DiligentCore/Graphics/GraphicsTools/interface",
        "./DiligentCore/Graphics/GraphicsTools/include"
    }
    files
    {
        "./DiligentCore/Graphics/GraphicsEngine/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsEngineNextGenBase/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsAccessories/src/**.cpp",
        "./DiligentCore/Graphics/ShaderTools/src/**.cpp",
        "./DiligentCore/Graphics/GraphicsTools/src/**.cpp"
    }

function AddCompileShadersCommands()
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

    local compiledShadersDir = "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders/GenerateMips/"
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

        -- Optional: Add the compiled header to your project if needed
        files { compiledShader }
    end
end

project "DiligentGraphicsImpl"
    CommonConfig()
    links { "DiligentCommon", "DiligentPlatforms", "DiligentGraphics" }
    filter "system:windows"
        systemversion "latest"
        defines
        {
            "PLATFORM_WIN32",
            "D3D12_SUPPORTED"
        }
        includedirs
        {
            "./DiligentCore/Common/interface",
            "./DiligentCore/Primitives/interface",
            "./DiligentCore/Platforms/interface",
            "./DiligentCore/Platforms/Basic/interface",
            "./DiligentCore/Platforms/Win32/interface",
            "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
            "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
            "./DiligentCore/Graphics/GraphicsEngine/interface",
            "./DiligentCore/Graphics/GraphicsEngine/include",
            "./DiligentCore/Graphics/GraphicsEngineNextGenBase/include",
            "./DiligentCore/Graphics/GraphicsAccessories/interface",
            "./DiligentCore/Graphics/ShaderTools/interface",
            "./DiligentCore/Graphics/ShaderTools/include",
            "./DiligentCore/Graphics/GraphicsTools/interface",
            "./DiligentCore/Graphics/GraphicsTools/include",
            "./DiligentCore/Graphics/GraphicsEngineD3DBase/include",
            "./DiligentCore/Graphics/GraphicsEngineD3DBase/interface",
            "./DiligentCore/Graphics/GraphicsEngineD3D12/include",
            "./DiligentCore/Graphics/GraphicsEngineD3D12/interface",
            "./DiligentCore/Graphics/GraphicsEngineD3D12/shaders",
            "./DiligentCore/ThirdParty/DirectXShaderCompiler"
        }
        files
        {
            "./DiligentCore/Graphics/GraphicsEngineD3D12/src/**.cpp",
            "./DiligentCore/Graphics/GraphicsEngineD3DBase/src/**.cpp"
        }
        AddCompileShadersCommands()
    filter "system:linux"
        systemversion "latest"
        defines
        {
            "PLATFORM_LINUX",
            "GL_SUPPORTED"
        }
        includedirs
        {
            "./DiligentCore/Common/interface",
            "./DiligentCore/Primitives/interface",
            "./DiligentCore/Platforms/interface",
            "./DiligentCore/Platforms/Basic/interface",
            "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
            "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
            "./DiligentCore/Graphics/GraphicsEngine/interface",
            "./DiligentCore/Graphics/GraphicsAccessories/interface",
            "./DiligentCore/Graphics/ShaderTools/interface",
            "./DiligentCore/Graphics/GraphicsTools/interface",
            "./DiligentCore/Graphics/GraphicsEngineOpenGL/include",
            "./DiligentCore/Graphics/GraphicsEngineOpenGL/interface",
        }
        files
        {
            "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/**.cpp"
        }
    filter "system:macosx"
        systemversion "latest"
        defines
        {
            "PLATFORM_MACOS",
            "GL_SUPPORTED"
        }
        includedirs
        {
            "./DiligentCore/Common/interface",
            "./DiligentCore/Primitives/interface",
            "./DiligentCore/Platforms/interface",
            "./DiligentCore/Platforms/Basic/interface",
            "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
            "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
            "./DiligentCore/Graphics/GraphicsEngine/interface",
            "./DiligentCore/Graphics/GraphicsAccessories/interface",
            "./DiligentCore/Graphics/ShaderTools/interface",
            "./DiligentCore/Graphics/GraphicsTools/interface",
            "./DiligentCore/Graphics/GraphicsEngineOpenGL/include",
            "./DiligentCore/Graphics/GraphicsEngineOpenGL/interface",
        }
        files
        {
            "./DiligentCore/Graphics/GraphicsEngineOpenGL/src/**.cpp"
        }

project "DiligentTools"
    CommonConfig()
    links { "DiligentCommon", "DiligentPlatforms", "DiligentHLSL2GLSLConverter" }
    includedirs
    {
        "./DiligentCore/Common/include",
        "./DiligentCore/Common/interface",
        "./DiligentCore/Primitives/interface",
        "./DiligentCore/Platforms/interface",
        "./DiligentCore/Platforms/Basic/interface",
        "./DiligentCore/Platforms/Basic/include",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/include",
        "./DiligentCore/Graphics/GraphicsEngine/interface",
        "./DiligentCore/Graphics/GraphicsEngine/include",
        "./DiligentCore/Graphics/GraphicsAccessories/interface",
        "./DiligentCore/Graphics/ShaderTools/interface",
        "./DiligentCore/Graphics/ShaderTools/include",
        "./DiligentCore/Graphics/GraphicsTools/interface",
        "./DiligentCore/Graphics/GraphicsTools/include",
        "./DiligentTools/**/include/**.h",
        "./DiligentTools/**/interface/**.h"
    }
    files
    {

        "./DiligentTools/**/src/**.cpp"
    }

project "DiligentFX"
    CommonConfig()
    links { "DiligentCommon", "DiligentPlatforms", "DiligentHLSL2GLSLConverter", "DiligentTools" }
    includedirs
    {
        "./DiligentCore/Common/include",
        "./DiligentCore/Common/interface",
        "./DiligentCore/Primitives/interface",
        "./DiligentCore/Platforms/interface",
        "./DiligentCore/Platforms/Basic/interface",
        "./DiligentCore/Platforms/Basic/include",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/interface",
        "./DiligentCore/Graphics/HLSL2GLSLConverterLib/include",
        "./DiligentCore/Graphics/GraphicsEngine/interface",
        "./DiligentCore/Graphics/GraphicsEngine/include",
        "./DiligentCore/Graphics/GraphicsAccessories/interface",
        "./DiligentCore/Graphics/ShaderTools/interface",
        "./DiligentCore/Graphics/ShaderTools/include",
        "./DiligentCore/Graphics/GraphicsTools/interface",
        "./DiligentCore/Graphics/GraphicsTools/include",
        "./DiligentTools/**/include/**.h",
        "./DiligentTools/**/interface/**.h",
        "./DiligentFX/**/include",
        "./DiligentFX/**/interface"
    }
    files
    {
        "./DiligentFX/**/src/**.cpp"
    }

project "DiligentEngine"
    CommonConfig()
    links { "DiligentCommon", "DiligentPlatforms", "DiligentHLSL2GLSLConverter", "DiligentTools", "DiligentFX" }