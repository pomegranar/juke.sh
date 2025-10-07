
#!/usr/bin/env bash
# Kitty "Now Playing" viewer — stable geometry, proper skeleton, controls

hide_cursor()   { printf '\e[?25l'; }
show_cursor()   { printf '\e[?25h'; }
clear_screen()  { printf '\033[2J\033[H'; }

cleanup() {
    show_cursor
    stty echo
    clear_screen
    kitty +kitten icat --clear 2>/dev/null
    exit
}
trap cleanup INT TERM
trap 'needs_redraw=1' WINCH

hide_cursor
stty -echo -icanon time 0 min 0
clear_screen

TEXT_BOX_WIDTH=40
needs_redraw=1
last_art=""
last_title=""
# remember last known art size in cells so skeleton matches
last_w_cells=20
last_h_cells=10

PLACEHOLDER="/tmp/kitty_nowplaying_placeholder.png"
make_placeholder() {
    if [[ ! -f "$PLACEHOLDER" ]]; then
        if command -v convert >/dev/null 2>&1; then
            convert -size 512x512 xc:'#1e1e1e' -gravity center \
                -fill '#6c6c6c' -pointsize 28 -annotate 0 'No Art' \
                "$PLACEHOLDER" 2>/dev/null || PLACEHOLDER=""
        else
            PLACEHOLDER=""  # ImageMagick not available; fall back to text
        fi
    fi
}

draw_ui() {
    clear_screen
    kitty +kitten icat --clear 2>/dev/null

    term_w=$(tput cols)
    term_h=$(tput lines)

    cyan='\033[36m'; magenta='\033[35m'; yellow='\033[33m'
    gray='\033[90m'; reset='\033[0m';  ugray='\033[4;90m'

    # start from last known cell size
    img_w_cells=$last_w_cells
    img_h_cells=$last_h_cells

    # defaults that won't crash
    th=$img_h_cells
    aspect_ratio=100

    # update cell size if we have a local image and identify
    if [[ -n "$art" && -f "$art" && -r "$art" ]] && command -v identify >/dev/null 2>&1; then
        if read -r img_w img_h < <(identify -format "%w %h" "$art" 2>/dev/null); then
            # approximate: 1 cell ~ 8x16 px (tweak if needed)
            # ensure minimum size of 5x5 cells to avoid weirdness
            tw=$(( img_w / 8 ))
            th=$(( img_h / 16 ))
            (( tw < 5 )) && tw=5
            (( th < 5 )) && th=5
            img_w_cells=$tw
            img_h_cells=$th
            last_w_cells=$img_w_cells
            last_h_cells=$img_h_cells
            # aspect ratio x100 to avoid float math
            (( img_h > 0 )) && aspect_ratio=$(( img_w * 100 / img_h ))
        fi
    fi

    total_w=$((img_w_cells + 8 + TEXT_BOX_WIDTH))
    total_h=$img_h_cells

    # center block
    off_x=$(( (term_w - total_w) / 2 - 1 ))
    off_y=$(( (term_h - th) / 2 + 3))
    (( off_x < 0 )) && off_x=0
    (( off_y < 0 )) && off_y=0

    text_x=$((off_x + img_w_cells + 4))
    if (( aspect_ratio > 160 )); then
        text_y=$((off_y + img_h_cells / 2 ))
    else
        text_y=$((off_y + img_h_cells / 2 - 3))
    fi
    (( text_y < 0 )) && text_y=0

    # album art, placeholder, or fallback text
    if [[ -n "$art" && -f "$art" && -r "$art" ]]; then
        kitty +kitten icat \
          --place "${img_w_cells}x${img_h_cells}@${off_x}x${off_y}" \
          "$art" 2>/dev/null
    else
        make_placeholder
        if [[ -n "$PLACEHOLDER" && -f "$PLACEHOLDER" ]]; then
          kitty +kitten icat \
            --place "${img_w_cells}x${img_h_cells}@${off_x}x${off_y}" \
            "$PLACEHOLDER" 2>/dev/null
        else
          cx=$((off_x + img_w_cells/2 - 5))
          cy=$((off_y + img_h_cells/2))
          (( cx < 0 )) && cx=0
          (( cy < 0 )) && cy=0
          tput cup "$cy" "$cx"; printf "${gray}[ No Art ]${reset}"
        fi
    fi

    # info panel
    tput cup $((text_y-2)) $text_x
    if [[ "$ui_state" == "no_player" ]]; then
        printf "${gray}┌─ No media players ────────────────────────┐${reset}"
        tput cup $text_y $text_x;       printf "${gray}  Let's play some music!            ${reset}"
        tput cup $((text_y+2)) $text_x; printf "${gray}└───────────────────────────────────────────┘${reset}"
    elif [[ "$ui_state" == "no_track" ]]; then
        printf "${gray}┌─ Waiting for track ───────────────────────┐${reset}"
        tput cup $text_y $text_x;       printf "${gray}  …no track is currently playing…            ${reset}"
        tput cup $((text_y+2)) $text_x; printf "${gray}└───────────────────────────────────────────┘${reset}"
    else
        printf "${gray}┌─ Now Playing ─────────────────────────────┐${reset}"
        tput cup $((text_y-1)) $text_x; printf "${gray}│${reset}${cyan} Title:${reset}  %-34.34s" "${title:-—}"
        tput cup $text_y        $text_x; printf "${gray}│${reset}${magenta} Artist:${reset} %-33.33s" "${artist:-—}"
        tput cup $((text_y+1))  $text_x; printf "${gray}│${reset}${yellow} Album:${reset}  %-34.34s" "${album:-—}"
        tput cup $((text_y+2))  $text_x; printf "${gray}└───────────────────────────────────────────┘${reset}"
    fi

    # controls
    tput cup $((text_y+4)) $text_x
    printf "${gray}[${reset}${ugray}P${reset}${gray}ause]${reset} 󰐎  ${gray}  [${ugray}B${reset}${gray}ack]${reset} 󰒮 ${gray}  [${ugray}N${reset}${gray}ext]${reset} 󰒭 ${gray}  [${ugray}Q${reset}${gray}uit]${reset}   "
}

# simple helpers
have_players() {
    playerctl -l 2>/dev/null | sed '/^\s*$/d' | wc -l | awk '{exit !($1>0)}'
}
player_status() {
    playerctl status 2>/dev/null || true
}

while true; do
    # keys
    key=$(dd bs=1 count=1 2>/dev/null)
    case "$key" in
        " "|p) playerctl play-pause 2>/dev/null ;;
        n)   playerctl next 2>/dev/null ;;
        b)   playerctl previous 2>/dev/null ;;
        q|Q) cleanup ;;
    esac

    ui_state="playing"
    art=""
    title=""
    artist=""
    album=""

    if ! have_players; then
        ui_state="no_player"
    else
        status="$(player_status)"
        case "$status" in
            Playing|Paused)
                # metadata (quiet during track gaps)
                art=$(playerctl metadata mpris:artUrl 2>/dev/null | sed 's|file://||')
                title=$(playerctl metadata xesam:title 2>/dev/null)
                artist=$(playerctl metadata xesam:artist 2>/dev/null)
                album=$(playerctl metadata xesam:album 2>/dev/null)
                # if everything is empty, treat as no_track
                if [[ -z "$title$artist$album" ]]; then
                    ui_state="no_track"
                fi
                ;;
            *)
                ui_state="no_track"
                ;;
        esac
    fi

    # redraw on change, resize, or when metadata state changes
    if [[ "$needs_redraw" == "1" || "$art" != "$last_art" || "$title" != "$last_title" || "$ui_state" != "$last_state" ]]; then
        draw_ui
        last_art="$art"
        last_title="$title"
        last_state="$ui_state"
        needs_redraw=0
    fi

    sleep 0.5
done

