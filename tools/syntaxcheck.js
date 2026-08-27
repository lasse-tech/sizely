const GLib = imports.gi.GLib;
const ByteArray = imports.byteArray;
const System = imports.system;

let failed = 0;

for (const path of ARGV) {
    let src;
    try {
        const [ok, bytes] = GLib.file_get_contents(path);
        if (!ok) {
            throw new Error("file not readable");
        }
        src = ByteArray.toString(bytes);
    } catch (e) {
        printerr("FAIL    " + path + ": " + e.message);
        failed++;
        continue;
    }

    try {
        new Function(src);
        print("OK      " + path);
    } catch (e) {
        printerr("FAIL    " + path + ": " + e);
        failed++;
    }
}

System.exit(failed > 0 ? 1 : 0);
