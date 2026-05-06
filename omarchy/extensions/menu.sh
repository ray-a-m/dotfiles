#!/usr/bin/env bash
# Custom Omarchy menu. Sourced by /usr/share/omarchy/bin/omarchy-menu just
# before its dispatch, so redefining show_*_menu functions here overrides the
# stock ones. The stock script is left untouched (survives package upgrades).
#
# Top-level layout: Mail / Research / Files / Portals / System.
#
# Dropped from main: Apps (use SUPER+SPACE), Learn, Trigger, Setup, Install,
# Remove, Update, About. They're still reachable via `omarchy-menu <name>`
# from a terminal. Style is folded into System.

# Override Omarchy's menu() to hide the search input. Walker's --nosearch
# applies in dmenu mode; passing it via the extra-args slot is the same
# vector Omarchy uses for things like preselect index. Search is unwanted
# in the omarchy menu — the list is fixed and we navigate it with j/k.
menu() {
  local prompt="$1"
  local options="$2"
  local extra="$3"
  local preselect="$4"

  read -r -a args <<<"$extra"

  if [[ -n $preselect ]]; then
    local index
    index=$(echo -e "$options" | grep -nxF "$preselect" | cut -d: -f1)
    if [[ -n $index ]]; then
      args+=("-c" "$index")
    fi
  fi

  echo -e "$options" | omarchy-launch-walker --dmenu --nosearch --width 295 --minheight 1 --maxheight 630 -p "$prompt…" "${args[@]}" 2>/dev/null
}

show_main_menu() {
  case $(menu "Go" "󰇮  Mail\n󰂺  Research\n󰉋  Files\n󰖟  Portals\n  System") in
    *Mail*)     show_mail_menu ;;
    *Research*) show_research_menu ;;
    *Files*)    show_files_menu ;;
    *Portals*)  show_portals_menu ;;
    *System*)   show_system_menu ;;
  esac
}

show_mail_menu() {
  case $(menu "Mail" "  Personal\n  Professional\n  UIC") in
    *Personal*)     gtk-launch personal-gmail ;;
    *Professional*) gtk-launch fastmail ;;
    *UIC*)          gtk-launch uic-email ;;
    *)              show_main_menu ;;
  esac
}

show_research_menu() {
  case $(menu "Research" "Zotero\n  UIC Library\n  Claude\n  ChatGPT\n  Obsidian") in
    *Zotero*)   gtk-launch zotero ;;
    *Library*)  gtk-launch uic-library ;;
    *Claude*)   gtk-launch claude ;;
    *ChatGPT*)  gtk-launch chatgpt ;;
    *Obsidian*) gtk-launch obsidian ;;
    *)          show_main_menu ;;
  esac
}

show_files_menu() {
  case $(menu "Files" "  Dropbox\n  Personal\n  UIC") in
    *Dropbox*)  gtk-launch dropbox ;;
    *Personal*) gtk-launch personal-gdrive ;;
    *UIC*)      gtk-launch uic-gdrive ;;
    *)          show_main_menu ;;
  esac
}

show_portals_menu() {
  case $(menu "Portals" "  Blackboard\nAdmin\nEditor\n  GitHub") in
    *Blackboard*) gtk-launch blackboard ;;
    *Admin*)      gtk-launch wordpress-admin ;;
    *Editor*)     gtk-launch wordpress-editor ;;
    *GitHub*)     gtk-launch GitHub ;;
    *)            show_main_menu ;;
  esac
}

# Two-option confirm prompt for destructive actions. Returns 0 on Yes,
# 1 on Cancel/Esc/h. Defaults the highlight to Cancel so a stray
# `l` after picking Shutdown doesn't actually shut down.
confirm() {
  [[ "$(menu "$1" "Cancel\nYes" "" "Cancel")" == "Yes" ]]
}

# Prepend Style to omarchy's stock System menu; preserve the rest of its
# items (Screensaver/Lock/Suspend/Hibernate/Logout/Restart/Shutdown) verbatim.
# Restart and Shutdown go through confirm() to avoid accidental triggers
# (l after misclicking the menu item shuts down without it).
show_system_menu() {
  local options="Style\nScreensaver\nLock"
  ! omarchy-toggle-enabled suspend-off && options="$options\nSuspend"
  omarchy-hibernation-available && options="$options\nHibernate"
  options="$options\nLogout\nRestart\nShutdown"

  case $(menu "System" "$options") in
    *Style*)       show_style_menu ;;
    *Screensaver*) omarchy-launch-screensaver force ;;
    *Lock*)        omarchy-system-lock ;;
    *Suspend*)     systemctl suspend ;;
    *Hibernate*)   systemctl hibernate ;;
    *Logout*)      confirm "Log out?"  && omarchy-system-logout   || show_system_menu ;;
    *Restart*)     confirm "Restart?"  && omarchy-system-reboot   || show_system_menu ;;
    *Shutdown*)    confirm "Shut down?" && omarchy-system-shutdown || show_system_menu ;;
    *)             show_main_menu ;;
  esac
}
