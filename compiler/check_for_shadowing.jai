// #load this file in your equivalent of make.jai, and in your message loop call `check_for_shadowing`.
// It will report any shadowing as a warning by default, but you can optionally make it error instead.


check_for_shadowing :: (message: *Message, report_as_error := false) {
    if message.kind == {
        case .TYPECHECKED;
        code := cast(*Message_Typechecked) message;
        for decl: code.declarations {
            if decl.filename == "" || contains(decl.filename, "modules")
                continue;

            for expr: decl.expressions
                if (expr.kind == .PROCEDURE_HEADER)
                    table_set(*headers, cast(*Code_Procedure_Header) expr, false);

            if decl.name == ""
            || decl.type.type == .PROCEDURE
            || decl.flags & .IS_STRUCT_MEMBER
                continue;

            // global constants have no root expression, but global variables have a LITERAL container?
            if decl.root_expression
            && ((decl.flags & .IS_CONSTANT) || decl.root_expression.kind != .LITERAL)
                continue;

            table_set(*global_variables, decl.name, decl);
        }

        case .COMPILATION_PHASE;
        phase := cast (*Message_Phase) message;
        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
            report_as := ifx report_as_error then Report.ERROR else Report.WARNING;
            for checked, header: headers {
                if checked  continue;
                if header.body_or_null {
                    for argument, index: header.arguments
                        store_local_variable(index, argument.name, cast(*Code_Node) argument);
                    last_parameter_index = header.arguments.count - 1;
                    check_block(header.body_or_null.block, last_parameter_index, report_as);

                    table_set(*headers, header, true);
                }
            }
        }
    }

    check_block :: (block: *Code_Block, locals_head: int, report_as: Report) {
        next_head := locals_head;

        for variable: block.members
            next_head = check_variable(variable, next_head, report_as);

        for statement: block.statements {
            if statement.kind == {
                case .BLOCK;
                check_block(cast(*Code_Block) statement, next_head, report_as);

                case .PUSH_CONTEXT;
                check_block((cast(*Code_Push_Context) statement).block, next_head, report_as);

                case .DEFER;
                check_block((cast(*Code_Defer) statement).block, next_head, report_as);

                case .WHILE;
                check_block((cast(*Code_While) statement).block, next_head, report_as);

                case .IF;
                then_block := (cast(*Code_If) statement).then_block;
                else_block := (cast(*Code_If) statement).else_block;
                if then_block  check_block(then_block, next_head, report_as);
                if else_block  check_block(else_block, next_head, report_as);

                case .CASE;
                check_block((cast(*Code_Case) statement).then_block, next_head, report_as);

                case .FOR;
                code_for := cast(*Code_For) statement;
                for_head := next_head;

                if code_for.ident_decl && code_for.ident_decl.name != "it"
                    for_head = check_variable(code_for.ident_decl, for_head, report_as);

                if code_for.index_decl && code_for.index_decl.name != "it_index"
                    for_head = check_variable(code_for.index_decl, for_head, report_as);

                check_block(code_for.block, for_head, report_as);
            }
        }
    }

    check_variable :: (variable: *Code_Scope_Entry, locals_head: int, report_as: Report) -> next_head: int, added: bool {
        next_head := locals_head;

        value, found := table_find(global_variables, variable.name);
        if found && value != variable {
            compiler_report(sprint("\nShadowing global: original at %\n", format_location(value)), loc = make_location(variable), mode = report_as);
            print("### % ###\n", variable.name);
        }
        else {
            found := false;
            for < index: locals_head..0 {
                local := local_variables[index];
                if local.name == variable.name {
                    if index <= last_parameter_index
                        compiler_report(sprint("\nShadowing parameter: original at %\n", format_location(local.node)), loc = make_location(variable), mode = report_as);
                    else
                        compiler_report(sprint("\nShadowing local: original at %\n", format_location(local.node)), loc = make_location(variable), mode = report_as);
                    found = true;
                    break;
                }
            }

            if !found {
                next_head += 1;
                local : Local_Variable = ---;
                local.name = variable.name;
                local.node = variable;

                if next_head > local_variables.count - 1
                    array_add(*local_variables, local);
                else
                    local_variables[next_head] = local;
            }
        }

        return next_head, next_head > locals_head;
    }
}


#scope_file


format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%,%", location.fully_pathed_filename, location.line_number, location.character_number);
}


store_local_variable :: (index: int, name: string, node: *Code_Node) {
    local : Local_Variable = ---;
    local.name = name;
    local.node = node;
    if local_variables.count <= index {
        while local_variables.count <= index
            array_add(*local_variables, local);
    }
    else {
        local_variables[index] = local;
    }
}


Local_Variable :: struct {
    name : string;
    node : *Code_Node;
}

local_variables : [..] Local_Variable;
last_parameter_index := -1;

global_variables : Table(string, *Code_Node);
headers : Table(*Code_Procedure_Header, bool);
