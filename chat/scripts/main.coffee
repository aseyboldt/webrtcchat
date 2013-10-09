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
        peer: null

    validate: (attrs, options) =>
        return null

    start: =>
        peer = new Peer
            id: @get 'name'
            key: @get 'server_key'
            host: 'localhost'
            port: 9000
            debug: 2
        @set peer: peer
        peer.on 'error', (e) =>
            alert e
        peer.on 'open', =>
            @set id: (@get 'peer').id
            @trigger 'open'
        peer.on 'close', =>
            alert "connection to server closed"
        peer.on 'connection', (conn) =>
            @trigger 'request_conn'


class LocalUserView extends backbone.View
    el: $('#local-user')

    initialize: ->
        @render()
        @model.on 'change', =>
            @render()

    render: =>
        template = require('../templates/local_user.jade')
        @$el.html template @model.toJSON()


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
        @model.on 'add', (message) =>
            @add message

    render: =>
        @$el.html @template()

    add: (message) =>
        message_view = new MessageView
            model: message
        @model.add(message)
        @elements[message_view.model.id] = message


class Contact extends backbone.Model

    defaults:
        name: "anonymus"
        conn: null
        messages: null
        online: false

    initialize: ->
        @set messages: new MessageList

        @on 'change:conn', (model, conn) =>
            if @previous('conn')?
                @previous('conn').close()
            if conn?
                conn.on 'data', (data) =>
                    @recv data
                conn.on 'close', =>
                    @trigger 'close'
                    @set conn: null
                conn.on 'error' (e) =>
                    alert e

    connect: (peer) =>
        conn = peer.connect(id: @get 'id')
        @set conn: conn

    send: (message) =>
        if not @conn? or not @ready
            @trigger 'conn:error', "No active connection"
        else
            (@get 'conn').send(message.text)
            messages.add(message)

    resv: (data) =>
        message = new Message
            text: data
            from: @get 'name'
        @messages.add message


class ContactList extends backbone.Collection
    model: Contact

    initialize: =>
        "todo: set @active_contact, @input"

    activate: (contact) =>
        "todo"


class ContactView extends backbone.View
    el: '#contact-list'

    initialize: ->
        @template = require('../templates/contact.jade')
        @messages_view
        @render()

    render: =>
        @$el.append @template @model.toJSON()


class ContactListView extends backbone.View
    el: '#contacts'

    initialize: ->
        @template = require('../templates/contact_list.jade')
        @local_user = @options['local_user']
        @elements = {}
        @render()

        $('#btn-add-contact').click =>
            $('#add-contact-dialog').modal('show')

        $('#btn-save-contact').click =>
            new_contact = new Contact
                name: $('#add-contact-name').val()
                id: $('#add-contact-id').val()
            @add(new_contact)
            $('#add-contact-dialog').modal('hide')

        @local_user.on('request_conn'), @request_conn

    add: (contact) =>
        contact_view = new ContactView
            model: contact
        @elements[contact.id] = contact_view
        @model.add(contact)

    render: =>
        @$el.html @template()

    request_conn: (conn) =>
        # if contact exists: choose it
        #
        # else: create new Contact and ContactView...
        #
        # Switch Input to contact and show corresponding MessageListView
        if @model.has_contact(conn)
            # open dialog: ask if user wants to accept connection
            # Return if not
        else
            # open dialog: ask if user wants to accept connection and ask
            # for name. Return if not
        contact = null # corresponding contact
        @model.activate(contact)


# show dialog to ask for name
# save result in new object in window
show_name_dialog = (local_user) ->
    dialog_template = require('../templates/name_dialog.jade')
    $('body').append dialog_template()
    $('#name-dialog').modal('show')
    name = $('#local-user-name')
    server_key = $('#server-key')
    $('#btn-save-name-dialog').click ->
        local_user.set
            name: name.val()
            server_key: server_key.val()
        if not local_user.isValid()
            name.parent().addClass('has-error')
            server_key.parent().addClass('has-error')
        else
            $('#name-dialog').modal('hide')
            local_user.connect()


$ ->
    $('#sidebar').affix()

    local_user = new LocalUserModel
    local_user_view = new LocalUserView
        model: local_user

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

    contacts = new ContactList
    contacts_view = new ContactListView
        model: contacts

    active_contact = null
    message_list_view = null

    local_user.on 'open', =>

        local_user.on 'connection', =>
            contact = new Contact

        contacts.on 'add', (contact) =>
            active_contact = contact
            message_list_view = new MessageListView
                model: active_contact.get 'messages'

            editor.on "keyup", (cm, event) ->
                if event.which == 13 and event.shiftKey
                    message = new Message
                    message.set
                        from: local_user.get 'name'
                        text: editor.getValue()
                    editor.setValue("")
                    active_contact.send message
