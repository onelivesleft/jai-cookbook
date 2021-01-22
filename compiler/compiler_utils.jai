format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%,%", location.fully_pathed_filename, location.line_number, location.character_number);
}


/*
name_from_scope :: (node: *Code_Node) -> string {
    // assumes decl filename is meta.jai

    //print("%,% - %,%\n", node.l0, node.c0, node.l1, node.c1);
    if node.l1 < node.l0  return "ERR";
    if node.l1 == node.l0 && node.c1 <= node.c0  return "ERR";

    start := source_line_offset[node.l0 - 1] + node.c0 - 1;
    end   := source_line_offset[node.l1 - 1] + node.c1 - 1;

    return slice(source_text, start, end - start);
}
*/


has_note :: (notes: [] *Code_Note, note: string) -> bool {
    for notes  if it.text == note  return true;
    return false;
}


make_code_range :: (node: *Code_Node) -> Source_Code_Range {
    range : Source_Code_Range = ---;
    range.fully_pathed_filename  = node.filename;
    range.line_number_start      = node.l0;
    range.line_number_end        = node.l1;
    range.character_number_start = node.c0;
    range.character_number_end   = node.c1;
    return range;
}
