var CodeMirror = {
    modes: {},
    mimes: {},
    defineMode: function(mode, def) {
        CodeMirror.modes[mode] = def;
    },
    defineMIME: function(mime, mode) {
        CodeMirror.mimes[mime] = mode;
    }
};

module.exports = CodeMirror;
