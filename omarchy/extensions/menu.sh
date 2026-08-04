#!/usr/bin/env bash
# Custom Omarchy menu. Sourced by /usr/share/omarchy/bin/omarchy-menu just
# before its dispatch, so redefining show_*_menu functions here overrides the
# stock ones. The stock script is left untouched (survives package upgrades).
#
# Top-level layout: Mail / Emacs / Research / Files / Portals / System.
# (File Explorer is on SUPER+E, so it's omitted here.)
#
# Note on back-nav: walker's `-c` flag only paints a visual mark, and walker
# hard-sets cursor to row 0 in dmenu mode (set_autoselect(true) in upstream).
# So "remember where I was" via cursor relocation isn't achievable without
# patching walker or reordering the input (which shifts display order). For
# now, the back path just re-opens the parent menu cleanly with the cursor
# at the top.
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
  case $(menu "Go" "󰇮  Mail\n  Emacs\n󰂺  Research\n󰉋  Files\n󰖟  Portals\n  System") in
    *Mail*)     show_mail_menu ;;
    *Emacs*)    gtk-launch emacsclient ;;
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
  case $(menu "Research" "  ChatGPT\n  Claude\n  UIC Library\nZotero") in
    *ChatGPT*)     gtk-launch chatgpt ;;
    *Claude*)      gtk-launch claude ;;
    *Library*)     gtk-launch uic-library ;;
    *Zotero*)      gtk-launch zotero ;;
    *)             show_main_menu ;;
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
  case $(menu "Portals" "  Canvas\n  GitHub") in
    *Canvas*)     gtk-launch canvas ;;
    *GitHub*)     gtk-launch github ;;
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
# items (Screensaver/Lock/Suspend/Hibernate/Restart/Shutdown) verbatim.
# Restart and Shutdown go through confirm() to avoid accidental triggers
# (l after misclicking the menu item shuts down without it).
#
# Logout is deliberately omitted. Securing this machine = Lock (hyprlock),
# never Logout — a logout drops to the SDDM Wayland greeter, which renders
# the plain white login theme instead of the ThinkPad Plymouth screen (and
# can wedge un-repainted on a re-negotiated output). Relogin=true only
# auto-recovers from that; it still flashes. No Hyprland keybind reaches
# logout, so removing this entry closes the only GUI path. The rare
# intentional logout is still available as `omarchy logout` from a terminal.
show_system_menu() {
  local options="Style\nScreensaver\nLock"
  ! omarchy-toggle-enabled suspend-off && options="$options\nSuspend"
  omarchy-hibernation-available && options="$options\nHibernate"
  options="$options\nRestart\nShutdown"

  case $(menu "System" "$options") in
    *Style*)       show_style_menu ;;
    *Screensaver*) omarchy-launch-screensaver force ;;
    *Lock*)        omarchy-system-lock ;;
    *Suspend*)     systemctl suspend ;;
    *Hibernate*)   systemctl hibernate ;;
    *Restart*)     confirm "Restart?"  && omarchy-system-reboot   || show_system_menu ;;
    *Shutdown*)    confirm "Shut down?" && omarchy-system-shutdown || show_system_menu ;;
    *)             show_main_menu ;;
  esac
}
