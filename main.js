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


var editor = CodeMirror.fromTextArea(document.getElementById("text-input"), {
    mode: 'markdown',
    lineNumbers: true,
    theme: "default"
});


function showMessage(message) {
    $('#log').append($('<li/>', {html: marked(message)}));
    MathJax.Hub.Queue(["Typeset", MathJax.Hub, "log"]);
};


editor.on("change", function (cm, changeObj) {
    var preview = document.getElementById("preview");
    preview.innerHTML = marked(editor.getValue());
    MathJax.Hub.Queue(["Typeset", MathJax.Hub, "preview"]);
});


function startChat(conn) {
    conn.on('data', function(data) {
        showMessage(data);
    });

    editor.on("keyup", function (cm, event) {
        if (event.which == 13 && event.shiftKey) {
            conn.send(editor.getValue());
            editor.setValue("");
        }
    });
};


$('#listenForm').submit(function() {
    var localId = $('#localIdForm').val();
    var serverKey = $('#serverKeyForm').val();

    var peer = new Peer(localId, {key: serverKey});


    peer.on('connection', function (conn) {
        startChat(conn);
    });

    $('#connectForm').submit(function() {
        var remoteId = $('#remoteIdForm').val();
        var conn = peer.connect(remoteId);
        conn.on('open', function () {
            startChat(conn);
        });
        return false;
    });
    return false;
});



