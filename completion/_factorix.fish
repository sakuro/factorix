# Fish completion for factorix
# Output by: factorix completion fish

# Helper function to get installed MOD names
function __factorix_installed_mods
    factorix mod list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null
end

# Helper function to check if we're completing a specific subcommand
function __factorix_using_command
    set -l cmd (commandline -opc)
    set -l argc (count $cmd)

    if test $argc -eq 1
        return 1
    end

    for i in (seq 2 $argc)
        switch $cmd[$i]
            case '-*'
                continue
            case '*'
                if test "$cmd[$i]" = "$argv[1]"
                    return 0
                end
                return 1
        end
    end
    return 1
end

# Helper function to check nested subcommand
function __factorix_using_subcommand
    set -l cmd (commandline -opc)
    set -l argc (count $cmd)

    if test $argc -lt 3
        return 1
    end

    set -l parent $argv[1]
    set -l sub $argv[2]

    set -l found_parent 0
    for i in (seq 2 $argc)
        switch $cmd[$i]
            case '-*'
                continue
            case '*'
                if test $found_parent -eq 0
                    if test "$cmd[$i]" = "$parent"
                        set found_parent 1
                    else
                        return 1
                    end
                else
                    if test "$cmd[$i]" = "$sub"
                        return 0
                    end
                    return 1
                end
        end
    end
    return 1
end

# Disable file completion by default
complete -c factorix -f

# Global options
complete -c factorix -s c -l config-path -d 'Path to configuration file' -r
complete -c factorix -l log-level -d 'Set log level' -xa 'debug info warn error fatal'
complete -c factorix -s q -l quiet -d 'Suppress non-essential output'

# Top-level commands
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a version -d 'Display Factorix version'
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a man -d 'Display the Factorix manual page'
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a launch -d 'Launch Factorio game'
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a path -d 'Display Factorio and Factorix paths'
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a mod -d 'MOD management commands'
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a cache -d 'Cache management commands'
complete -c factorix -n "not __factorix_using_command version; and not __factorix_using_command man; and not __factorix_using_command launch; and not __factorix_using_command path; and not __factorix_using_command mod; and not __factorix_using_command cache; and not __factorix_using_command completion" -a completion -d 'Generate shell completion script'

# launch options
complete -c factorix -n "__factorix_using_command launch" -s w -l wait -d 'Wait for the game to finish'

# path options
complete -c factorix -n "__factorix_using_command path" -l json -d 'Output in JSON format'

# completion subcommands
complete -c factorix -n "__factorix_using_command completion" -a zsh -d 'Generate zsh completion script'
complete -c factorix -n "__factorix_using_command completion" -a bash -d 'Generate bash completion script'
complete -c factorix -n "__factorix_using_command completion" -a fish -d 'Generate fish completion script'

# cache subcommands
complete -c factorix -n "__factorix_using_command cache" -a stat -d 'Display cache statistics'
complete -c factorix -n "__factorix_using_command cache" -a evict -d 'Evict cache entries'

# cache stat options
complete -c factorix -n "__factorix_using_subcommand cache stat" -l json -d 'Output in JSON format'

# cache evict options
complete -c factorix -n "__factorix_using_subcommand cache evict" -l all -d 'Remove all entries'
complete -c factorix -n "__factorix_using_subcommand cache evict" -l expired -d 'Remove expired entries only'
complete -c factorix -n "__factorix_using_subcommand cache evict" -l older-than -d 'Remove entries older than AGE' -r
complete -c factorix -n "__factorix_using_subcommand cache evict" -a 'download api info_json' -d 'Cache name'

# mod subcommands
complete -c factorix -n "__factorix_using_command mod" -a check -d 'Check MOD dependencies'
complete -c factorix -n "__factorix_using_command mod" -a list -d 'List installed MODs'
complete -c factorix -n "__factorix_using_command mod" -a show -d 'Show MOD details from Factorio MOD Portal'
complete -c factorix -n "__factorix_using_command mod" -a enable -d 'Enable MODs'
complete -c factorix -n "__factorix_using_command mod" -a disable -d 'Disable MODs'
complete -c factorix -n "__factorix_using_command mod" -a install -d 'Install MODs from Factorio MOD Portal'
complete -c factorix -n "__factorix_using_command mod" -a uninstall -d 'Uninstall MODs'
complete -c factorix -n "__factorix_using_command mod" -a update -d 'Update MODs'
complete -c factorix -n "__factorix_using_command mod" -a download -d 'Download MODs without installing'
complete -c factorix -n "__factorix_using_command mod" -a upload -d 'Upload MOD to Factorio MOD Portal'
complete -c factorix -n "__factorix_using_command mod" -a edit -d 'Edit MOD metadata on Factorio MOD Portal'
complete -c factorix -n "__factorix_using_command mod" -a search -d 'Search MODs on Factorio MOD Portal'
complete -c factorix -n "__factorix_using_command mod" -a sync -d 'Sync MOD states from a save file'
complete -c factorix -n "__factorix_using_command mod" -a image -d 'MOD image management'
complete -c factorix -n "__factorix_using_command mod" -a settings -d 'MOD settings management'

# mod list options
complete -c factorix -n "__factorix_using_subcommand mod list" -l enabled -d 'Show only enabled MODs'
complete -c factorix -n "__factorix_using_subcommand mod list" -l disabled -d 'Show only disabled MODs'
complete -c factorix -n "__factorix_using_subcommand mod list" -l errors -d 'Show only MODs with dependency errors'
complete -c factorix -n "__factorix_using_subcommand mod list" -l outdated -d 'Show only MODs with available updates'
complete -c factorix -n "__factorix_using_subcommand mod list" -l json -d 'Output in JSON format'

# mod enable/disable options
complete -c factorix -n "__factorix_using_subcommand mod enable" -s y -l yes -d 'Skip confirmation prompts'
complete -c factorix -n "__factorix_using_subcommand mod enable" -a '(__factorix_installed_mods)' -d 'MOD name'
complete -c factorix -n "__factorix_using_subcommand mod disable" -s y -l yes -d 'Skip confirmation prompts'
complete -c factorix -n "__factorix_using_subcommand mod disable" -a '(__factorix_installed_mods)' -d 'MOD name'

# mod install options
complete -c factorix -n "__factorix_using_subcommand mod install" -s y -l yes -d 'Skip confirmation prompts'
complete -c factorix -n "__factorix_using_subcommand mod install" -s j -l jobs -d 'Number of parallel downloads' -r

# mod uninstall options
complete -c factorix -n "__factorix_using_subcommand mod uninstall" -s y -l yes -d 'Skip confirmation prompts'
complete -c factorix -n "__factorix_using_subcommand mod uninstall" -l all -d 'Uninstall all MODs'
complete -c factorix -n "__factorix_using_subcommand mod uninstall" -a '(__factorix_installed_mods)' -d 'MOD name'

# mod update options
complete -c factorix -n "__factorix_using_subcommand mod update" -s y -l yes -d 'Skip confirmation prompts'
complete -c factorix -n "__factorix_using_subcommand mod update" -s j -l jobs -d 'Number of parallel downloads' -r
complete -c factorix -n "__factorix_using_subcommand mod update" -a '(__factorix_installed_mods)' -d 'MOD name'

# mod download options
complete -c factorix -n "__factorix_using_subcommand mod download" -s d -l directory -d 'Download directory' -ra '(__fish_complete_directories)'
complete -c factorix -n "__factorix_using_subcommand mod download" -s j -l jobs -d 'Number of parallel downloads' -r
complete -c factorix -n "__factorix_using_subcommand mod download" -s r -l recursive -d 'Include required dependencies recursively'

# mod upload options
complete -c factorix -n "__factorix_using_subcommand mod upload" -l description -d 'Markdown description' -r
complete -c factorix -n "__factorix_using_subcommand mod upload" -l category -d 'MOD category' -xa 'content overhaul tweaks utilities scenarios mod-packs localizations internal no-category'
complete -c factorix -n "__factorix_using_subcommand mod upload" -l license -d 'License identifier' -xa 'default_mit default_gnugplv3 default_gnulgplv3 default_mozilla2 default_apache2 default_unlicense'
complete -c factorix -n "__factorix_using_subcommand mod upload" -l source-url -d 'Repository URL' -r
complete -c factorix -n "__factorix_using_subcommand mod upload" -ra '(__fish_complete_suffix .zip)'

# mod edit options
complete -c factorix -n "__factorix_using_subcommand mod edit" -l description -d 'Markdown description' -r
complete -c factorix -n "__factorix_using_subcommand mod edit" -l summary -d 'Brief description' -r
complete -c factorix -n "__factorix_using_subcommand mod edit" -l title -d 'MOD title' -r
complete -c factorix -n "__factorix_using_subcommand mod edit" -l category -d 'MOD category' -xa 'content overhaul tweaks utilities scenarios mod-packs localizations internal no-category'
complete -c factorix -n "__factorix_using_subcommand mod edit" -l tags -d 'Tags' -xa 'transportation logistics trains combat armor enemies character environment planets mining fluids logistic-network circuit-network manufacturing power storage blueprints cheats'
complete -c factorix -n "__factorix_using_subcommand mod edit" -l license -d 'License identifier' -xa 'default_mit default_gnugplv3 default_gnulgplv3 default_mozilla2 default_apache2 default_unlicense'
complete -c factorix -n "__factorix_using_subcommand mod edit" -l homepage -d 'Homepage URL' -r
complete -c factorix -n "__factorix_using_subcommand mod edit" -l source-url -d 'Repository URL' -r
complete -c factorix -n "__factorix_using_subcommand mod edit" -l faq -d 'FAQ text' -r
complete -c factorix -n "__factorix_using_subcommand mod edit" -l deprecated -d 'Deprecation flag'
complete -c factorix -n "__factorix_using_subcommand mod edit" -l no-deprecated -d 'Clear deprecation flag'

# mod search options
complete -c factorix -n "__factorix_using_subcommand mod search" -l hide-deprecated -d 'Hide deprecated MODs'
complete -c factorix -n "__factorix_using_subcommand mod search" -l no-hide-deprecated -d 'Show deprecated MODs'
complete -c factorix -n "__factorix_using_subcommand mod search" -l page -d 'Page number' -r
complete -c factorix -n "__factorix_using_subcommand mod search" -l page-size -d 'Results per page' -r
complete -c factorix -n "__factorix_using_subcommand mod search" -l sort -d 'Sort field' -xa 'name created_at updated_at'
complete -c factorix -n "__factorix_using_subcommand mod search" -l sort-order -d 'Sort order' -xa 'asc desc'
complete -c factorix -n "__factorix_using_subcommand mod search" -l version -d 'Filter by Factorio version' -r
complete -c factorix -n "__factorix_using_subcommand mod search" -l json -d 'Output in JSON format'

# mod sync options
complete -c factorix -n "__factorix_using_subcommand mod sync" -s y -l yes -d 'Skip confirmation prompts'
complete -c factorix -n "__factorix_using_subcommand mod sync" -s j -l jobs -d 'Number of parallel downloads' -r
complete -c factorix -n "__factorix_using_subcommand mod sync" -ra '(__fish_complete_suffix .zip)'

# mod image subcommands
complete -c factorix -n "__factorix_using_subcommand mod image" -a list -d 'List MOD images'
complete -c factorix -n "__factorix_using_subcommand mod image" -a add -d 'Add an image to a MOD'
complete -c factorix -n "__factorix_using_subcommand mod image" -a edit -d 'Edit MOD images'

# mod settings subcommands
complete -c factorix -n "__factorix_using_subcommand mod settings" -a dump -d 'Dump MOD settings to JSON'
complete -c factorix -n "__factorix_using_subcommand mod settings" -a restore -d 'Restore MOD settings from JSON'
