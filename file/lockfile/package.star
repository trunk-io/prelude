native.file(
    name = "lockfile",
    globs = [
        # Cargo (Rust)
        "**/Cargo.lock",

        # CocoaPods (Swift/Obj-C)
        "**/Podfile.lock",

        # Composer (PHP)
        "**/composer.lock",

        # Conan (C++)
        "**/conan.lock",

        # Golang
        "**/go.mod",
        "**/go.sum",

        # Gradle (Android/Java/Kotlin)
        "**/buildscript-gradle.lockfile",
        "**/gradle.lockfile",

        # Maven
        "**/pom.xml",

        # Mix (Erlang/Elixir)
        "**/mix.lock",

        # Node
        "**/package-lock.json",
        "**/pnpm-lock.yaml",
        "**/yarn.lock",

        # NuGet (.NET)
        "**/packages.lock.json",
        "**/packages.config",

        # Pub (Dart)
        "**/pubspec.lock",

        # Python
        "**/requirements.txt",
        "**/Pipfile.lock",
        "**/poetry.lock",
        "**/pdm.lock",

        # Ruby
        "**/Gemfile.lock",

        # R
        "**/renv.lock",
    ],
)
