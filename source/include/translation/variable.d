module include.translation.variable;

import include.from;

string[] translateVariable(in from!"clang".Cursor cursor,
                           in from!"include.runtime.options".Options options =
                                  from!"include.runtime.options".Options())
    @safe
{
    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;
    import std.typecons: No;

    assert(cursor.kind == Cursor.Kind.VarDecl);

    // variables can be declared multiple times in C but only one in D
    if(!cursor.isCanonical) return [];

    return [text("extern __gshared ",
                 translate(cursor.type, No.translatingFunction, options), " ", cursor.spelling, ";")];
}
