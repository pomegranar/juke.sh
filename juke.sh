
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
# remember last known art size in cells so skeleton matches
last_w_cells=20
last_h_cells=10

PLACEHOLDER="/tmp/kitty_nowplaying_placeholder.png"
make_placeholder() {
    if [[ ! -f "$PLACEHOLDER" ]]; then
        # simple 512x512 dark canvas with centered "No Art"
        convert -size 512x512 xc:'#1e1e1e' -gravity center \
            -fill '#6c6c6c' -pointsize 28 -annotate 0 'No Art' \
            "$PLACEHOLDER" 2>/dev/null || PLACEHOLDER=""
    fi
}

draw_ui() {
    # wipe text and image layers
    clear_screen
    kitty +kitten icat --clear 2>/dev/null

    term_w=$(tput cols)
    term_h=$(tput lines)

    cyan='\033[36m'; magenta='\033[35m'; yellow='\033[33m'
    gray='\033[90m'; reset='\033[0m'

    # compute art size in cells
    img_w_cells=$last_w_cells
    img_h_cells=$last_h_cells
    if [[ -f "$art" ]]; then
        if read img_w img_h < <(identify -format "%w %h" "$art" 2>/dev/null); then
            # approx kitty cell metrics; tweak if needed
            tw=$((img_w_cells * img_h_cells / (img_h / 16) ))
            th=$((img_h / 16))
            (( tw > 4 )) && img_w_cells=$tw
            (( th > 4 )) && img_h_cells=$th
            last_w_cells=$img_w_cells
            last_h_cells=$img_h_cells
        fi
    fi

    total_w=$((img_w_cells + 4 + TEXT_BOX_WIDTH))
    total_h=$img_h_cells
    off_x=$(( (term_w - total_w) / 2 ))
    off_y=$(( (term_h - total_h) / 2 + 1))
    (( off_x < 0 )) && off_x=0
    (( off_y < 0 )) && off_y=0

    text_x=$((off_x + img_w_cells + 4))
    text_y=$((off_y + img_h_cells / 2 - 2))

    # draw album art or skeleton with icat at the SAME place/size
    if [[ -f "$art" ]]; then
        kitty +kitten icat \
          --place "${img_w_cells}x${img_h_cells}@${off_x}x${off_y}" \
          "$art" 2>/dev/null
    else
        make_placeholder
        if [[ -n "$PLACEHOLDER" ]]; then
          kitty +kitten icat \
            --place "${img_w_cells}x${img_h_cells}@${off_x}x${off_y}" \
            "$PLACEHOLDER" 2>/dev/null
        else
          # ultra-fallback: centered text in the art box
          cx=$((off_x + img_w_cells/2 - 5))
          cy=$((off_y + img_h_cells/2))
          tput cup $cy $cx; printf "${gray}[ No Art ]${reset}"
        fi
    fi

    # info panel
    tput cup $((text_y-2)) $text_x
    if [[ -n "$title" ]]; then
        printf "${gray}┌─ Now Playing ─────────────────────────────┐${reset}"
        tput cup $((text_y-1)) $text_x; printf "${cyan}Title:${reset}  %-34.34s" "$title"
        tput cup $text_y        $text_x; printf "${magenta}Artist:${reset} %-33.33s" "$artist"
        tput cup $((text_y+1))  $text_x; printf "${yellow}Album:${reset}  %-34.34s" "$album"
        tput cup $((text_y+2))  $text_x; printf "${gray}└───────────────────────────────────────────┘${reset}"
    else
        printf "${gray}┌─ Waiting for track ───────────────────────┐${reset}"
        tput cup $text_y $text_x;     printf "${gray}  …loading player metadata…                  ${reset}"
        tput cup $((text_y+2)) $text_x; printf "${gray}└───────────────────────────────────────────┘${reset}"
    fi

    # controls
    tput cup $((text_y+4)) $text_x
    printf "${gray}[Space]${reset} Play/Pause   ${gray}[n]${reset} Next   ${gray}[p]${reset} Prev"
}

while true; do
    # keys
    key=$(dd bs=1 count=1 2>/dev/null)
    case "$key" in
        " ") playerctl play-pause 2>/dev/null ;;
        n)   playerctl next 2>/dev/null ;;
        p)   playerctl previous 2>/dev/null ;;
    esac

    # metadata (quiet during track gaps)
    art=$(playerctl metadata mpris:artUrl 2>/dev/null | sed 's|file://||')
    title=$(playerctl metadata xesam:title 2>/dev/null)
    artist=$(playerctl metadata xesam:artist 2>/dev/null)
    album=$(playerctl metadata xesam:album 2>/dev/null)

    # redraw on change, resize, or when metadata missing
    if [[ "$art" != "$last_art" || "$needs_redraw" == "1" || -z "$title" ]]; then
        draw_ui
        last_art="$art"
        needs_redraw=0
    fi

    sleep 0.5
done

