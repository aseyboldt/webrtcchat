$ = require('jquery-browserify')
_ = require('underscore')
hljs = require('highlight.js')
marked = require('marked')
codemirror = require('code-mirror')
backbone = require('backbone')
jade = require('jade-runtime')
bootstrap = require('../../node_modules/twitter-bootstrap-3.0.0/dist/js/bootstrap.js')
#peerjs = require('./lib/peerjs/dist/peer.js')

backbone.$ = $

# tell marked to highlight source code
# and sanitize the input
marked.setOptions
    highlight: (code, lang) ->
        if hljs.LANGUAGES[lang]
            return hljs.highlight(lang, code).value
        else
            return hljs.highlightAuto(code).value
    sanitize: true


class LocalUserModel extends backbone.Model

    defaults:
        name: 'anonymus'
        server_key: 0
        id: 123456


    validate: (attrs, options) =>
        if attrs.name != 'hallo'
            return "invalid name (testing...)"


class LocalUserView extends backbone.View
    el: $('#local-user')

    initialize: ->
        @render()

    render: =>
        template = require('../templates/local_user.jade')
        @$el.html template
            local_user: @model.toJSON()

class InputModel extends backbone.Model

    defaults:
        text: ""


class InputView extends backbone.View
    el: $('#preview')

    initialize: ->
        @render

    render: =>
        @$el.html marked @model.get 'text'
        if MathJax?
            MathJax.Hub.Queue(["Typeset", MathJax.Hub, "preview"])


class Message extends backbone.Model

    defaults:
        text: ""
        time: ""
        from: ""
        id: 1

class MessageList extends backbone.Collection

    model: Message


class MessageView extends backbone.View
    el: '#message-list'

    initialize: ->
        @template = require('../templates/message.jade')
        @render()

    render: =>
        message_data = @model.toJSON()
        message_data['text'] = marked message_data['text']
        @$el.append @template message_data
        if MathJax?
            MathJax.Hub.Queue(["Typeset", MathJax.Hub, @el])

class MessageListView extends backbone.View
    el: '#log'

    initialize: ->
        @elements = {}
        @template = require('../templates/message_list.jade')
        @render()

    render: =>
        @$el.html @template()

    add: (message) =>
        message_view = new MessageView
            model: message
        @model.add(message)
        @elements[message_view.model.id] = message


# show dialog to ask for name
# save result in new object in window
show_name_dialog = (local_user) ->
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
    $('#sidebar').affix()
    #$('#input-area').affix()

    local_user = new LocalUserModel
    local_user_view = new LocalUserView
        model: local_user

    local_user.on("change", local_user_view.render)

    show_name_dialog(local_user)

    input_model = new InputModel
    input_view = new InputView
        model: input_model

    input_model.on("change", input_view.render)

    editor = codemirror.fromTextArea $('#text-input').get(0),
        mode: 'markdown'
        lineNumbers: true
        theme: 'default'
        height: 5

    editor.on "change", (cm, change_obj) ->
        input_model.set
            text: editor.getValue()

    message_list = new MessageList
    message_list_view = new MessageListView
        model: message_list

    editor.on "keyup", (cm, event) ->
        if event.which == 13 and event.shiftKey
            message = new Message
            message.set
                from: local_user.get 'name'
                text: editor.getValue()
            editor.setValue("")
            message_list_view.add message
