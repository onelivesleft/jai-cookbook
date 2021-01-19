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
