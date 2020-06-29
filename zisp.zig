const std = @import("std");

pub fn main() anyerror!void
{
    const stdOut = std.io.getStdOut().outStream();

//    
//    try stdOut.print("{}\n", .{ Program.rawCodeString });
//
    try Program.printTo(stdOut);
    try stdOut.print("{}\n", .{ Program.outerTokens.len });
//
    try stdOut.print("{}\n", .{ Program.tokenCount });
//
//    for (Program._arrStackLens) |len|try stdOut.print("{} ", .{ len });

}

const lisp = @embedFile("program.zisp");
const Program = try Compile(lisp);

const TokenType = enum {
    Block,
    Identifier,
    Number,
    Operator,
};

const TokenData = union(TokenType) {
    Block: []const Token,
    Identifier: []const u8,
    Number: []const u8,
    Operator: []const u8,
};

const Token = struct {
    line: usize,
    number: usize,
    data: TokenData
};

fn untilDelim(slice: []const u8, delims: []const u8) []const u8 {
    for (slice) |v, i| for (delims) |delim| if (delim == v) return slice[0..i];
    
    return slice;
}


fn parseOperator(slice: []const u8) ?[]const u8 {
    var i: usize = 0;

    if (i < slice.len) switch (slice[i]) {
        '?', '+', '-', '*', '/', '>', '|', '&', '^', '!' => {
            i += 1;
            if (i < slice.len and slice[i] == '=') i += 1;
        },
        '<' => {
            i += 1;
            if (i < slice.len and (slice[i] == '>' or slice[i] == '=')) i += 1;
        },
        else => return null
    };

    if (i < slice.len) switch (slice[i]) {
        '(', ')', ' ', '\t', '\n' => {},
        '\r' => {},
        else => return null
    };

    return slice[0..i];
}

fn parseNumber(slice: []const u8) ?[]const u8 {
    var i: usize = 0;

    if (i < slice.len and slice[i] == '-') i += 1;

    if (i < slice.len) switch (slice[i]) {
        '0' => i += 1,
        '1'...'9' => {
            i += 1;
            while (i < slice.len) switch (slice[i]) {
                '0'...'9' => i += 1,
                else => break
            };
        },
        else => return null
    }
    else return null;
    
    if (i < slice.len and slice[i] == '.'){
        i += 1;
        while (i < slice.len) switch (slice[i]) {
            '0'...'9' => i += 1,
            else => break
        };
    }

    if (i < slice.len and slice[i] == 'e') { 
        i += 1;
        if (i < slice.len and slice[i] == '-') i += 1;
        if (i < slice.len) switch (slice[i]) {
            '0'...'9' => {
                i += 1;
                while (i < slice.len) switch (slice[i]) {
                    '0'...'9' => i += 1,
                    else => break
                };
            },
            else => return null
        } 
        else return null;
    }

    if (i < slice.len) switch (slice[i]) {
        '(', ')', ' ', '\t', '\n' => {},
        '\r' => {},
        else => return null
    };

    return slice[0..i];
}

fn parseIdentifier(slice: []const u8) ?[]const u8 {
    var i: usize = 0;

    switch (slice[i]) { 
        'a'...'z', 'A'...'Z', '0'...'9', '_' => i += 1, 
        else => return null
    }

    while (i < slice.len) switch (slice[i]) { 
        'a'...'z', 'A'...'Z', '0'...'9', '_', '-' => i += 1, 
        else => break
    };

    if (i < slice.len) switch (slice[i]) {
        '(', ')', ' ', '\t', '\n' => {},
        '\r' => {},
        else => return null
    };

    return slice[0..i];
}

fn Compile(comptime code: []const u8) !type {
    
    var topTokens: []const Token = &[0] Token{};

    var stack: []const *Token = &[0] *Token{};
    
    var totalTokens: usize = 0;

    var currentBlock: ?*Token = null;

    //for (lines) |line, lineNumber| { 
        var i: usize = 0;

// Commented out code will be restored once regex lib is more complete
//        const regexEnding = "(?:(=?[\\s()])|$)";
//        const regexOps = "^(?:+|-|*|/|+=|-=|*=|/=|>|<|>=|<=|<=>|!=|==|\\||&|^|!|\\|=|&=|^=|!=)" ++ regexEnding;
//        const regexNumbers = "^-?(?:0|[1-9][0-9]*)(\\.[0-9]*)?(?:e-?[0-9]+)?" ++ regexEnding;
//        const regexIdentifiers = "^[a-zA-Z0-9_][a-zA-Z0-9_-]*" ++ regexEnding;
//
//        while (i < code.len) {
//            if (try regex.search("^[\\(\\)]", .{}, code[i..])) |matched_delimiter| {
//                i += matched_delimiter.slice.len;
//            }
//            else if (try regex.search("^\\s+", .{}, code[i..])) |matched_ws| {
//                i += matched_ws.slice.len;
//            }
//            else if (try regex.search(regexOps, .{}, code[i..])) |matched_operator| {
//                i += matched_operator.slice.len;
//            }
//            else if (try regex.search(regexNumbers, .{}, code[i..])) |matched_number| {
//                i += matched_number.slice.len;
//            }
//            else if (try regex.search(regexIdentifiers, .{}, code[i..])) |matched_identifier| {
//                i += matched_identifier.slice.len;
//            }
//            //TODO: A more explainatory error;
//            else @compileError("Unexpected character or string");
//            totalTokens += 1;
//        }
    //}
    loop: while (i < code.len) {
        // Consume whitespace
        while (true) {
            switch (code[i]) {
            ' ', '\t', '\n' => i += 1,
            '\r' => @compileError("Carriage return is not part of the zig standard"),
            else => break
            }
            if (i < code.len) {} else break :loop; 
        }

        if (code[i] == '(') {
            var newToken = Token{ .line = 0, .number = i, .data = .{ .Block = &[0]Token{} }  };
            if (currentBlock) |block| {
                switch (block.data) {
                    .Block => |*blockTokens| blockTokens.* = blockTokens.* ++ [1]Token{newToken},
                    else => @compileError("currentBlock is not a block")
                }
                stack = stack ++ [1]*Token{block};
            }
            else topTokens = topTokens ++ [1]Token{newToken};

            currentBlock = &newToken;
            
            i += 1;
        }
        else if (code[i] == ')') {
            
            if (stack.len > 0) {
                currentBlock = stack[stack.len - 1];
                stack = stack[0..stack.len - 1];
            }
            else if(currentBlock) |_| currentBlock = null
            else @compileError("Nothing to nest.");

            i += 1;
            continue :loop;
        }
        else if (parseOperator(code[i..])) |matched_operator| {
            var newToken = Token{ .line = 0, .number = i, .data = .{ .Operator = matched_operator }  };
            if (currentBlock) |block| {
                switch (block.data) {
                    .Block => |*blockTokens| blockTokens.* = blockTokens.* ++ [1]Token{newToken},
                    else => @compileError("currentBlock is not a block")
                }
            }
            
            i += matched_operator.len;
        }
        else if (parseNumber(code[i..])) |matched_number| {
            var newToken = Token{ .line = 0, .number = i, .data = .{ .Number = matched_number } };
            if (currentBlock) |block| {
                switch (block.data) {
                    .Block => |*blockTokens| blockTokens.* = blockTokens.* ++ [1]Token{newToken},
                    else => @compileError("currentBlock is not a block")
                }
            }
            i += matched_number.len;
        }
        else if (parseIdentifier(code[i..])) |matched_identifier| {
            var newToken = Token{ .line = 0, .number = i, .data = .{ .Identifier = matched_identifier } };
            if (currentBlock) |block| {
                switch (block.data) {
                    .Block => |*blockTokens| blockTokens.* = blockTokens.* ++ [1]Token{newToken},
                    else => @compileError("currentBlock is not a block")
                }
            }
            i += matched_identifier.len;
        }
        //TODO: A more explainatory error;
        else @compileError("Unexpected character or string: " ++ code[i]);
        totalTokens += 1;
    }
    //@compileLog(if (i == code.len) "Reached end of code" else "Did not reach end of code");
    
    return struct {
        const rawCodeString = code;
        const outerTokens = topTokens; 
        const tokenCount = totalTokens;
        const globals = .{};
        const procedures = .{};

        fn printToken(outStream: var, token: Token) anyerror!void {
            switch(token.data) {
                .Identifier => |slice| try outStream.print("{}", .{slice}),
                .Number => |slice| try outStream.print("{}", .{slice}),
                .Operator => |slice| try outStream.print("{}", .{slice}),
                .Block => |blockTokens| {
                    try outStream.print("(", .{});
                    for (blockTokens) |blockToken, index| {
                        try printToken(outStream, blockToken);
                        if (index < blockTokens.len - 1) try outStream.print(" ", .{});
                    }
                    try outStream.print(")", .{});
                },
            }
        }

        pub fn printTo(outStream: var) anyerror!void {
            for (outerTokens) |token| {
                try printToken(outStream, token);
                try outStream.print("\n", .{});
            }
        }
    };

}


