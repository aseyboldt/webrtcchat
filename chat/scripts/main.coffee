$ = require('jquery-browserify')
_ = require('underscore')
hljs = require('highlight.js')
marked = require('marked')
codemirror = require('code-mirror')
backbone = require('backbone')
jade = require('jade-runtime')
#peerjs = require('./lib/peer')

backbone.$ = $

# tell marked to highlight source code
marked.setOptions
    highlight: (code, lang) ->
        if hljs.LANGUAGES[lang]
            return hljs.highlight(lang, code).value
        else
            return hljs.highlightAuto(code).value


class LocalUserModel extends backbone.Model

    defaults:
        name: 'anonymus'
        server_key: 0
        id: 123456


    validate: (attrs, options) ->
        if attrs.name != 'hallo'
            return "invalid name (testing...)"


class LocalUserView extends backbone.View
    el: $ 'body'

    initialize: ->
        @render()

    render: ->
        html = require('../templates/local_user.jade')
        $(@el).append html
            local_user: @model.toJSON()

class InputModel extends backbone.Model

    defaults:
        text: ""


class InputView extends backbone.View
    el: $('#preview')

    initialize: ->
        _.bindAll @, 'render'
        @render

    render: ->
        @$el.html marked @model.get 'text'
        MathJax.Hub.Queue(["Typeset", MathJax.Hub, "preview"])





# show dialog to ask for name
# save result in new object in window
show_name_dialog = ->
    dialog_template = require('../templates/name_dialog.jade')
    $('#log').append dialog_template()
    name = $('#local-user-name')
    server_key = $('#server-key')
    $('#name-dialog').dialog
        modal: true
        buttons:
            "start": ->
                local_user.set
                    name: name.val()
                    server_key: server_key.val()
                if not local_user.isValid()
                    name.addClass('ui-state-error')
                    server_key.addClass('ui-state-error')
                else
                    $('#name-dialog').dialog("close")

$ ->
    local_user = new LocalUserModel
    local_user_view = new LocalUserView
        model: local_user

    show_name_dialog()


    input_model = new InputModel
    input_view = new InputView
        model: input_model

    input_model.on("change", input_view.render)


    editor = codemirror.fromTextArea $('#text-input').get(0),
        mode: 'markdown'
        lineNumbers: true
        theme: 'default'

    editor.on "change", (cm, change_obj) ->
        input_model.set
            text: editor.getValue()
