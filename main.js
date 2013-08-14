var marked = require('marked');
var codemirror = require('codemirror');
var hljs = require('highlight.js');

marked.setOptions({
    highlight: function(code, lang) {
        if (hljs.LANGUAGES[lang]) {
            console.log(hljs.highlightAuto(code).value);
            return hljs.highlight(lang, code).value;
        }
        else {
            console.log(hljs.highlightAuto(code).value);
            return hljs.highlightAuto(code).value;
        }
    }
});


function sendMessage(message) {
    console.log(message);
    $('#log').append($('<li/>', {html: marked(message)}));
    MathJax.Hub.Queue(["Typeset", MathJax.Hub, "log"]);
};

var editor = CodeMirror.fromTextArea(document.getElementById("text-input"), {
    mode: 'markdown',
    lineNumbers: true,
    theme: "default"
});


editor.on("change", function (cm, changeObj) {
    var preview = document.getElementById("preview");
    preview.innerHTML = marked(editor.getValue());
    MathJax.Hub.Queue(["Typeset", MathJax.Hub, "preview"]);
});


editor.on("keyup", function (cm, event) {
    if (event.which == 13 && event.shiftKey) {
        sendMessage(editor.getValue());
        editor.setValue("");
    }
});
