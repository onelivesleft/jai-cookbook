
format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%,%", location.fully_pathed_filename, location.line_number, location.character_number);
}
