// Walk all nodes from root on down, performing `action(node)` on each one.
// If `condition(node)` is false that node and its children will be ignored.
// Call `init_node_walk()` before doing anything else.


init_node_walk :: () {
    table_reset(*visited_serials);
}


revisit_node :: (node: *Code_Node) {
    table_remove(*visited_serials, node.serial);
}


found_node_count :: () -> int {
    return visited_serials.count;
}


walk_all_nodes :: (node: *Code_Node, condition: (*Code_Node) -> bool, action: (*Code_Node)) {
    if !node return;

    _, found := table_find(visited_serials, node.serial);
    if found return;

    table_set(*visited_serials, node.serial, node);

    if !condition(node) return;

    action(node);


    walk :: (node: *Code_Node) #expand {
        walk_all_nodes(node, `condition, `action);
    }


    if node.kind == {
        // @Note '// others: ' comments identify other Code_Node members,
        //       but which are not walked because they are not direct
        //       children of this node or would in some other way be walked
        //       from elsewhere in the tree.

        //case .UNINITIALIZED;
        // nop

        case .BLOCK;
        block := cast(*Code_Block) node;
        for block.members     walk(it);
        for block.statements  walk(it);
        walk(block.owning_statement);
        // others: parent

        case .LITERAL;
        literal := cast(*Code_Literal) node;
        if literal.value_type == {
            case .ARRAY;
            walk(literal.array_literal_info.element_type);
            for literal.array_literal_info.array_members  walk(it);

            case .STRUCT;
            walk(literal.struct_literal_info.type_expression);
            for literal.struct_literal_info.arguments  walk(it);
        }

        case .IDENT;
        ident := cast(*Code_Ident) node;
        walk(ident.resolved_declaration);

        case .UNARY_OPERATOR;
        unary := cast(*Code_Unary_Operator) node;
        walk(unary.subexpression);

        case .BINARY_OPERATOR;
        binary := cast(*Code_Binary_Operator) node;
        walk(binary.left);
        walk(binary.right);

        case .PROCEDURE_BODY;
        proc := cast(*Code_Procedure_Body) node;
        walk(proc.block);
        // others: header;

        case .PROCEDURE_CALL;
        proc := cast(*Code_Procedure_Call) node;
        walk(proc.procedure_expression);
        for argument: proc.arguments_unsorted {
            walk(argument.name);
            walk(argument.expression);
        }
        walk(proc.macro_expansion_block);
        // others: arguments_sorted

        //case .CONTEXT;
        // nop

        case .WHILE;
        _while := cast(*Code_While) node;
        walk(_while.condition);
        walk(_while.block);

        case .IF;
        _if := cast(*Code_If) node;
        walk(_if.condition);
        walk(_if.then_block);
        walk(_if.else_block);

        case .LOOP_CONTROL;

        case .CASE;
        _case := cast(*Code_Case) node;
        walk(_case.condition);
        walk(_case.then_block);
        // others: owning_if

        //case .REMOVE;
        //_remove := cast(*Code_Remove) node;
        //walk(_remove.target_ident);
        // others: target_ident

        case .RETURN;
        _return := cast(*Code_Return) node;
        for argument: _return.arguments_unsorted {
            walk(argument.name);
            walk(argument.expression);
        }
        // others: arguments_sorted

        case .FOR;
        _for := cast(*Code_For) node;
        walk(_for.iteration_expression);
        walk(_for.iteration_expression_right);
        walk(_for.want_pointer_expression);
        walk(_for.want_reverse_expression);
        walk(_for.ident_decl);
        walk(_for.index_decl);
        //if _for.macro_expansion_procedure_call
        //    walk(_for.macro_expansion_procedure_call);
        //else
            walk(_for.block);

        // case .TYPE_DEFINITION;
        // nop

        case .TYPE_INSTANTIATION;
        _type := cast(*Code_Type_Instantiation) node;
        walk(_type.type_valued_expression);
        walk(_type.type_of_lambda);
        walk(_type.pointer_to);
        walk(_type.array_element_type);
        walk(_type.array_dimension);

        case .ENUM;
        _enum := cast(*Code_Enum) node;
        walk(_enum.internal_type_inst);
        walk(_enum.block);

        case .PROCEDURE_HEADER;
        header := cast(*Code_Procedure_Header) node;
        walk(header.constants_block);
        for header.arguments  walk(it);
        for header.returns    walk(it);
        walk(header.my_header);
        walk(header.polymorph_source_header);
        for header.modify_directives  walk(it);
        walk(header.body_or_null);

        case .STRUCT;
        _struct := cast(*Code_Struct) node;
        walk(_struct.block);
        walk(_struct.constants_block);
        for _struct.notes  walk(it);

        case .COMMA_SEPARATED_ARGUMENTS;
        args := cast(*Code_Comma_Separated_Arguments) node;
        for args.expressions  walk(it);

        case .EXTRACT;
        extract := cast(*Code_Extract) node;
        walk(extract.from);

        case .SEQUENCE;
        sequence := cast(*Code_Sequence) node;
        for sequence.expressions  walk(it);
        walk(sequence.expression_i_replaced);

        case .MAKE_VARARGS;
        make := cast(*Code_Make_Varargs) node;
        for make.expressions  walk(it);

        case .DECLARATION;
        decl := cast(*Code_Declaration) node;
        walk(decl.type_inst);
        walk(decl.root_expression);
        //for decl.expressions  walk(it);
        walk(decl.alignment_expression);
        for decl.notes  walk(it);

        case .CAST;
        _cast := cast(*Code_Cast) node;
        walk(_cast.target_type);
        walk(_cast.expression);

        //case .DIRECTIVE_IMPORT;
        // ?

        //case .DIRECTIVE_INLINE;
        // ?

        // case .DIRECTIVE_THROUGH;
        // nop

        //case .DIRECTIVE_LOAD;
        // ?

        case .DIRECTIVE_RUN;
        run := cast(*Code_Directive_Run) node;
        walk(run.procedure);

        case .DIRECTIVE_CODE;
        code := cast(*Code_Directive_Code) node;
        walk(code.expression);

        case .DIRECTIVE_POKE_NAME;
        poke := cast(*Code_Directive_Poke_Name) node;
        walk(poke.module_struct);

        //case .DIRECTIVE_IF_DEFINED;  //  Not currently implemented.

        case .DIRECTIVE_BAKE;
        bake := cast(*Code_Directive_Bake) node;
        walk(bake.procedure_call);

        case .DIRECTIVE_MODIFY;
        modify := cast(*Code_Directive_Modify) node;
        walk(modify.block);

        //case .DIRECTIVE_FOREIGN_LIBRARY;
        // nop

        case .SIZE_OR_TYPE_INFO;
        size_or_type := cast(*Code_Size_Or_Type_Info) node;
        walk(size_or_type.type_to_query);
        walk(size_or_type.type_of_expression);

        case .PUSH_CONTEXT;
        push := cast(*Code_Push_Context) node;
        walk(push.to_push);
        walk(push.block);

        //case .NOTE;
        // nop

        //case .DIRECTIVE_PLACE;
        // nop

        //  case .DIRECTIVE_SCOPE;
        //  nop

        case .DIRECTIVE_STATIC_IF;
        _if := cast(*Code_Directive_Static_If) node;
        walk(_if.condition);
        walk(_if.then_block);
        walk(_if.else_block);

        case .DIRECTIVE_LOCATION;
        location := cast(*Code_Directive_Location) node;
        walk(location.ident);

        //case .DIRECTIVE_ALIGN;
        // ?

        //case .DIRECTIVE_ADD_CONTEXT;
        // ?

        case .COMPOUND_DECLARATION;
        compound := cast(*Code_Compound_Declaration) node;
        walk(compound.comma_separated_assignment);
        walk(compound.declaration_properties);
        walk(compound.alignment_expression);
        for compound.notes  walk(it);

        case .DEFER;
        _defer := cast(*Code_Defer) node;
        walk(_defer.block);

        case .USING;
        _using := cast(*Code_Using) node;
        walk(_using.expression);

        //case .PLACEHOLDER;
        // nop
    }
}


#scope_file


#import "Compiler";
#import "Hash_Table";


visited_serials: Table(s64, *Code_Node);
