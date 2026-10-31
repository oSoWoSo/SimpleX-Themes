#!/usr/bin/env python3
import re, sys, subprocess, os

COLOR_MAP = {
    '#0b1120': 'background', '#152642': 'sentMessage',
    '#212638': 'receivedMessage', '#38bdf8': 'accent',
    '#64748b': 'secondary', '#2a2f45': 'receivedReply',
    '#1a3050': 'sentReply', '#1f2937': 'menus',
    '#374151': 'secondaryVariant', '#3b82f6': 'title',
    '#9ca3af': 'secondary', '#67e8f9': 'accentVariant',
    '#10b981': 'accentVariant2', '#134e4a': 'secondaryVariant',
    '#22d3ee': 'accentVariant', '#267be5': 'title',
    '#70f0f9': 'accent', '#1298a5': 'accentVariant',
    '#8b8786': 'secondary', '#2c464d': 'secondaryVariant',
    '#121c37': 'menus', '#111528': 'background',
}

def read_theme_colors(theme_file):
    colors = {}
    in_colors = False
    for line in open(theme_file):
        if line.strip() == 'colors:':
            in_colors = True; continue
        if in_colors and re.match(r'^[a-zA-Z]', line):
            in_colors = False
        if in_colors:
            m = re.match(r'^\s+(\w+):\s*"#([0-9a-fA-F]{8})"', line)
            if m:
                colors[m.group(1)] = m.group(2)[2:]
    return colors

def render_svg(svg_template, theme_file, output_path):
    colors = read_theme_colors(theme_file)
    svg = open(svg_template).read()
    for svg_color, theme_key in COLOR_MAP.items():
        if theme_key in colors:
            svg = svg.replace(svg_color, '#' + colors[theme_key])
    tmp_svg = output_path + '.svg'
    with open(tmp_svg, 'w') as f:
        f.write(svg)
    subprocess.run(['inkscape', tmp_svg, '--export-filename=' + output_path,
                    '--export-width=1440', '--export-height=2759'],
                   check=True, capture_output=True)
    os.remove(tmp_svg)
    return True

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: render_svg.py <svg_template> <theme_file> <output_png>")
        sys.exit(1)
    render_svg(sys.argv[1], sys.argv[2], sys.argv[3])
    print(f"Rendered {sys.argv[3]}")
