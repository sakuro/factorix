# Bash completion for factorix
# Output by: factorix completion bash

# Helper function to get installed MOD names
_factorix_installed_mods() {
  factorix mod list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null
}

_factorix() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cword=$COMP_CWORD
  local words=("${COMP_WORDS[@]}")

  local global_opts="-c --config-path --log-level -q --quiet"
  local confirmable_opts="-y --yes"

  # Top-level commands
  local commands="version man launch path mod cache completion"

  # mod subcommands
  local mod_commands="check list show enable disable install uninstall update download upload edit search sync image settings"

  # cache subcommands
  local cache_commands="stat evict"

  # mod image subcommands
  local image_commands="list add edit"

  # mod settings subcommands
  local settings_commands="dump restore"

  case "${words[1]}" in
    version|man)
      COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
      return
      ;;
    launch)
      COMPREPLY=($(compgen -W "$global_opts -w --wait" -- "$cur"))
      return
      ;;
    path)
      COMPREPLY=($(compgen -W "$global_opts --json" -- "$cur"))
      return
      ;;
    completion)
      if [[ $cword -eq 2 ]] && [[ "$cur" != -* ]]; then
        COMPREPLY=($(compgen -W "zsh bash fish" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
      fi
      return
      ;;
    cache)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$cache_commands" -- "$cur"))
      else
        case "${words[2]}" in
          stat)
            COMPREPLY=($(compgen -W "$global_opts --json" -- "$cur"))
            ;;
          evict)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts --all --expired --older-than" -- "$cur"))
            else
              COMPREPLY=($(compgen -W "download api info_json" -- "$cur"))
            fi
            ;;
          *)
            COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            ;;
        esac
      fi
      return
      ;;
    mod)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$mod_commands" -- "$cur"))
      else
        case "${words[2]}" in
          check)
            COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            ;;
          list)
            COMPREPLY=($(compgen -W "$global_opts --enabled --disabled --errors --outdated --json" -- "$cur"))
            ;;
          show)
            COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            ;;
          enable|disable)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts $confirmable_opts" -- "$cur"))
            else
              local mods=$(_factorix_installed_mods)
              COMPREPLY=($(compgen -W "$mods" -- "$cur"))
            fi
            ;;
          install)
            COMPREPLY=($(compgen -W "$global_opts $confirmable_opts -j --jobs" -- "$cur"))
            ;;
          uninstall)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts $confirmable_opts --all" -- "$cur"))
            else
              local mods=$(_factorix_installed_mods)
              COMPREPLY=($(compgen -W "$mods" -- "$cur"))
            fi
            ;;
          update)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts $confirmable_opts -j --jobs" -- "$cur"))
            else
              local mods=$(_factorix_installed_mods)
              COMPREPLY=($(compgen -W "$mods" -- "$cur"))
            fi
            ;;
          download)
            COMPREPLY=($(compgen -W "$global_opts -d --directory -j --jobs -r --recursive" -- "$cur"))
            ;;
          upload)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts --description --category --license --source-url" -- "$cur"))
            elif [[ "$prev" == "--category" ]]; then
              COMPREPLY=($(compgen -W "content overhaul tweaks utilities scenarios mod-packs localizations internal no-category" -- "$cur"))
            elif [[ "$prev" == "--license" ]]; then
              COMPREPLY=($(compgen -W "default_mit default_gnugplv3 default_gnulgplv3 default_mozilla2 default_apache2 default_unlicense" -- "$cur"))
            else
              COMPREPLY=($(compgen -f -X '!*.zip' -- "$cur"))
            fi
            ;;
          edit)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts --description --summary --title --category --tags --license --homepage --source-url --faq --deprecated --no-deprecated" -- "$cur"))
            elif [[ "$prev" == "--category" ]]; then
              COMPREPLY=($(compgen -W "content overhaul tweaks utilities scenarios mod-packs localizations internal no-category" -- "$cur"))
            elif [[ "$prev" == "--license" ]]; then
              COMPREPLY=($(compgen -W "default_mit default_gnugplv3 default_gnulgplv3 default_mozilla2 default_apache2 default_unlicense" -- "$cur"))
            elif [[ "$prev" == "--tags" ]]; then
              COMPREPLY=($(compgen -W "transportation logistics trains combat armor enemies character environment planets mining fluids logistic-network circuit-network manufacturing power storage blueprints cheats" -- "$cur"))
            fi
            ;;
          search)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts --hide-deprecated --no-hide-deprecated --page --page-size --sort --sort-order --version --json" -- "$cur"))
            elif [[ "$prev" == "--sort" ]]; then
              COMPREPLY=($(compgen -W "name created_at updated_at" -- "$cur"))
            elif [[ "$prev" == "--sort-order" ]]; then
              COMPREPLY=($(compgen -W "asc desc" -- "$cur"))
            fi
            ;;
          sync)
            if [[ "$cur" == -* ]]; then
              COMPREPLY=($(compgen -W "$global_opts $confirmable_opts -j --jobs" -- "$cur"))
            else
              COMPREPLY=($(compgen -f -X '!*.zip' -- "$cur"))
            fi
            ;;
          image)
            if [[ $cword -eq 3 ]]; then
              COMPREPLY=($(compgen -W "$image_commands" -- "$cur"))
            else
              case "${words[3]}" in
                add)
                  if [[ "$cur" == -* ]]; then
                    COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
                  elif [[ $cword -eq 5 ]]; then
                    COMPREPLY=($(compgen -f -X '!*.@(png|jpg|jpeg|gif)' -- "$cur"))
                  fi
                  ;;
                *)
                  COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
                  ;;
              esac
            fi
            ;;
          settings)
            if [[ $cword -eq 3 ]]; then
              COMPREPLY=($(compgen -W "$settings_commands" -- "$cur"))
            else
              COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            fi
            ;;
          *)
            COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            ;;
        esac
      fi
      return
      ;;
  esac

  # Top-level completion
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
  else
    COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
  fi
}

# Register the completion function
complete -F _factorix factorix
