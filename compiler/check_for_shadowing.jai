check_for_shadowing :: (message: *Compiler_Message, report_as_error := false) {
    if checked_for_shadowing  return;

    if message.kind == {
        case .CODE_TYPECHECKED;
        code := cast(*Compiler_Message_Code_Typechecked) message;
        for decl: code.declarations {
            if decl.filename == "" || contains(decl.filename, "modules")
                continue;

            for expr: decl.expressions
                if (expr.kind == .BLOCK)
                    array_add(*blocks, cast(*Code_Block) expr);

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
        phase := cast (*Compiler_Message_Compilation_Phase) message;
        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
            checked_for_shadowing = true;
            report_as := ifx report_as_error then Compiler_Report.ERROR else Compiler_Report.WARNING;
            for block: blocks
                check_block(block, -1, report_as);
        }
    }

    check_block :: (block: *Code_Block, locals_head: int, report_as: Compiler_Report) {
        if block.block_type != .IMPERATIVE return;

        next_head := locals_head;

        for variable: block.members {
            value, found := table_find(global_variables, variable.name);
            if found && value != variable {
                compiler_report(sprint("Shadowing global variable: original at %\n", format_location(value)), loc = make_location(variable), mode = report_as);
            }
            else {
                found := false;
                for index: 0..locals_head {
                    local := local_variables[index];
                    if local.name == variable.name {
                        compiler_report(sprint("Shadowing local variable: original at %\n", format_location(local.node)), loc = make_location(variable), mode = report_as);
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
        }

        for statement: block.statements {
            if statement.kind == .BLOCK {
                child := cast(*Code_Block) statement;
                check_block(child, next_head, report_as);
            }
        }
    }
}


#scope_file


format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%,%", location.fully_pathed_filename, location.line_number, location.character_number);
}


Local_Variable :: struct {
    name : string;
    node : *Code_Node;
}

local_variables : [..] Local_Variable;
global_variables : Table(string, *Code_Node);
blocks : [..] *Code_Block;

checked_for_shadowing := false;
