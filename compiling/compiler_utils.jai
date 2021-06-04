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


/*
make_code_range :: (node: *Code_Node) -> Source_Code_Range {
    range : Source_Code_Range = ---;
    range.fully_pathed_filename  = node.filename;
    range.line_number_start      = node.l0;
    range.line_number_end        = node.l1;
    range.character_number_start = node.c0;
    if node.kind == .DECLARATION {
        decl := cast(*Code_Declaration) node;
        range.character_number_end = range.character_number_start + decl.name.count;
    }
    else
        range.character_number_end = node.c1;
    return range;
}
*/


name_from_type_info :: (t: *Type_Info) -> name: string #must, valid: bool {
    if t.type == {
        case .INTEGER;
        integer := cast(*Type_Info_Integer)t;
        if integer.signed {
            if integer.runtime_size == {
                case 1;  return "s8", true;
                case 2;  return "s16", true;
                case 4;  return "s32", true;
                case 8;  return "s64", true;
            }
        }
        else {
            if integer.runtime_size == {
                case 1;  return "u8", true;
                case 2;  return "u16", true;
                case 4;  return "u32", true;
                case 8;  return "u64", true;
            }
        }

        case .FLOAT;
        if t.runtime_size == 4
            return "float32", true;
        else
            return "float64", true;


        case .POINTER;
        ptr := cast(*Type_Info_Pointer)t;
        name, valid := name_from_type_info(ptr.pointer_to);
        return sprint("*%", name), valid;

        case .BOOL;        return "bool", true;
        case .STRING;      return "string", true;
        case .VOID;        return "void", true;
        case .STRUCT;      return "struct", true;
        case .ANY;         return "Any", true;
        case .ENUM;        return "enum", true;
        case .TYPE;        return "type", true;
        case .CODE;        return "Code", true;
    }

    return "", false;
}
