# --- Zsh Options ---

setopt AUTO_CD              # cd by typing directory name
setopt INTERACTIVE_COMMENTS # allow comments in interactive shell
setopt HIST_IGNORE_DUPS     # no duplicate entries in history
setopt HIST_IGNORE_SPACE    # don't record commands starting with space
setopt SHARE_HISTORY        # share history between sessions

# --- History ---

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# --- Prompt ---

autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=(precmd_vcs_info)
setopt PROMPT_SUBST
zstyle ':vcs_info:git:*' formats '(%b) '
zstyle ':vcs_info:*' enable git

PROMPT='%F{green}%n%f@%F{blue}%m%f:%F{yellow}%~%f ${vcs_info_msg_0_}%F{magenta}$%f '

# --- PATH ---

export PATH="$HOME/arch/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/git/depot_tools:$PATH"
export PATH="/mnt/syno/scripts/cmos:$PATH"

# --- Plugins ---

# fzf-tab (fuzzy tab completion) - must be sourced after compinit
autoload -Uz compinit && compinit
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh

# fzf keybindings (Ctrl+R history, Ctrl+T files, Alt+C cd)
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# Autosuggestions (inline ghost text from history)
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Syntax highlighting (command coloring) - must be sourced last
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- Shared Config ---

[ -f "$HOME/.config/shell/aliases.sh" ] && source "$HOME/.config/shell/aliases.sh"
[ -f "$HOME/.config/shell/functions.sh" ] && source "$HOME/.config/shell/functions.sh"

# bun completions
[ -s "/home/nicholas/.bun/_bun" ] && source "/home/nicholas/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
