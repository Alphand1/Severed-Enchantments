-- set minimum xmake version
set_xmakever("3.1.1")

-- set project
set_project("SeveredEnchantments")
set_version("1.0.0")
set_license("GPL-3.0")
set_languages("c++23")
set_optimize("faster")
set_warnings("allextra", "error")

-- disable skyrim vr
set_config("skyrim_vr", false)

-- set policies
set_policy("package.requires_lock", true)

-- require packages
add_requires("toml++", "xbyak", { configs = { skse_xbyak = true } })

-- add CommonLibSSE-NG
includes("lib/commonlibsse-ng")

-- targets
target("SeveredEnchantments")

-- add packages to target
add_packages("fmt", "spdlog", "toml++", "xbyak")
add_deps("commonlibsse-ng")

-- add commonlibsse-ng plugin
add_rules("commonlibsse-ng.plugin", {
    name = "SeveredEnchantments",
    author = "Alphand"
})

-- add src files
add_files("source/**.cpp")
add_headerfiles("include/**.h", "include/**.hpp")
add_includedirs("include")
set_pcxxheader("include/PCH.h")
