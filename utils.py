def format_toc(pairs, dot_char='.', min_dots=10, prefix=' ', suffix=' '):
    '''
    pairs: list of tuples x, y to print toc

    Each line of output will be same length, assuming monospaced font

    Each line in the toc looks like:
    x ........ y
    '''
    line_length = max(sum(len(x) for x in pair) for pair in pairs)
    out_lines = []
    for pair in pairs:
        len_pair = sum(len(x) for x in pair)
        x, y = pair
        remaining_length = min_dots + line_length - len_pair
        line = x + prefix + remaining_length*dot_char + suffix + y
        out_lines.append(line)
    return '\n'.join(out_lines)
