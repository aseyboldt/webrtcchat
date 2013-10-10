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
    ### All data about the local user
    #
    # Attributes
    # ----------
    #
    # name : str
    #   Arbitrarily chosen name
    #
    # server_key : str
    #   The server of peerjs can use a key to identify users
    #
    # peer : peerjs.Peer
    #   Manages all incoming and outgoing connections
    #
    # Events
    # ------
    #
    # open
    #   Is triggerd, when @peer connected to the peerjs server
    #   and is ready to start or receive connections
    #
    # request_conn (peerjs.DataConnection)
    #   Is triggerd, when a remote use tries to connect
    ###

    defaults:
        name: 'anonymus'
        server_key: 0
        peer: null

    validate: (attrs, options) =>
        return null

    start: =>
        peer = new Peer
            id: @get 'name'
            key: @get 'server_key'
            debug: 3
        @set peer: peer
        peer.on 'error', (e) =>
            alert e
        peer.on 'open', =>
            @set id: (@get 'peer').id
            @trigger 'open'
        peer.on 'close', =>
            alert "connection to server closed"
        peer.on 'connection', (conn) =>
            alert 'connection request in local_user from ' + conn.id
            @trigger 'request_conn', conn


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
    ### A Model for the input of new messages
    #
    # Attributes
    # ----------
    #
    # text : str
    #   the current value of a not jet created message
    #
    # Events
    # ------
    #
    # send(Message)
    #   Triggerd if the a new message is ready to be send
    ###

    defaults:
        text: ""

    initialize: (options) ->
        @local_user = options['local_user']

        @on 'data', (data) =>
            message = new Message
                text: data
                from: @local_user.get 'name'
            @trigger 'send', message


class InputView extends backbone.View
    el: $('#input-area')

    initialize: ->
        @template = require('../templates/input_area.jade')
        @render()

        @editor = codemirror.fromTextArea $('#text-input').get(0),
            mode: 'markdown'
            lineNumbers: true
            firstLineNumbers: 10
            theme: 'default'
            height: 7

        @editor.on "change", (cm, change_obj) =>
            @model.set text: @editor.getValue()

        @editor.on "keyup", (cm, event) =>
            if event.which == 13 and event.shiftKey
                @model.trigger 'data', @editor.getValue()
                @editor.setValue("")

        @model.on 'change:text', @preview

    render: =>
        @$el.html @template()

    preview: =>
        $('#preview').html marked @model.get 'text'
        if MathJax?
            MathJax.Hub.Queue(["Typeset", MathJax.Hub, "preview"])


class Message extends backbone.Model

    defaults:
        text: ""
        time: ""
        from: ""


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
        @template = require('../templates/message_list.jade')
        @render()
        @model.on 'add', (message) =>
            message_view = new MessageView
                model: message

    render: =>
        @$el.html @template()


class Contact extends backbone.Model
    ### Represent another user
    #
    # Attributes
    # ----------
    #
    # name : str
    #   Arbitrary name for the other user
    #
    # messages : MessageList
    #   A collection of all messages to or from this user
    #
    # conn : peerjs.DataConnection
    #   A peerjs connection to this user. May be null
    #
    # Events
    # ------
    #
    #
    #
    ###

    defaults:
        name: "anonymus"
        conn: null
        messages: null

    initialize: (options) ->
        @set messages: new MessageList
        @local_user = options['local_user']

        @on 'error', (e) =>
            alert e

        @on 'change:conn', (model, conn) =>
            if @previous('conn')?
                @previous('conn').close()
            if conn?
                conn.on 'data', (data) =>
                    @recv data
                conn.on 'close', =>
                    @trigger 'close'
                    @set conn: null
                conn.on 'error', (e) =>
                    alert e

    connect: =>
        alert 'Try to connect to ' + @get 'id'
        conn = @local_user.get('peer').connect(id: @get 'id')
        @set conn: conn

    send: (message) =>
        messages = @get 'messages'
        alert message.get 'text'
        messages.add(message)
        if not @conn?
            @trigger 'error', "No active connection"
        else
            (@get 'conn').send(message.text)
            messages.add(message)

    resv: (data) =>
        message = new Message
            text: data
            from: @get 'name'
        @get('messages').add message


class ContactList extends backbone.Collection
    model: Contact

    initialize: (options) ->
        @active_contact = null
        @input = options['input']

        @input.on 'send', (message) =>
            if @active_contact?
                @active_contact.send message
            else
                alert "no active contact"

        @on 'select', @activate

    find_contact: (conn) =>
        return @find (contact) =>
            return conn.id == contact.get 'id'

    activate: (contact) =>
        alert "activating contact " + contact.get 'id'
        @active_contact = contact
        contact.connect()


class ContactView extends backbone.View
    el: '#contact-list'

    initialize: ->
        @template = require('../templates/contact.jade')
        @render()
        @messages_view = new MessageListView
            model: @model.get 'messages'
        @$el.click =>
            @model.trigger 'select', @model

    render: =>
        @$el.append @template @model.toJSON()
        @el = '#contact-' + @model.get 'id'


class ContactListView extends backbone.View
    el: '#contacts'

    initialize: (options) ->
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
                local_user: @local_user
            @add(new_contact)
            $('#add-contact-dialog').modal('hide')

        @local_user.on 'request_conn', @request_conn

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
        alert "Connection request from " + conn.id
        contact = @model.find_contact(conn)
        if contact?
            # open dialog: ask if user wants to accept connection
            # Return if not
            @model.trigger 'select', contact
        else
            # open dialog: ask if user wants to accept connection and ask
            # for name. Return if not
            alert ('contact unknown')


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
            local_user.start()


$ ->
    $('#sidebar').affix()

    local_user = new LocalUserModel
    local_user_view = new LocalUserView
        model: local_user

    show_name_dialog(local_user)

    input_model = new InputModel
        local_user: local_user
    input_view = new InputView
        model: input_model

    contacts = new ContactList
        input: input_model
    contacts_view = new ContactListView
        model: contacts
        local_user: local_user

    active_contact = null
    message_list_view = null

    """
    local_user.on 'open', =>

        local_user.on 'connection', =>
            contact = new Contact

        contacts.on 'add', (contact) =>
            active_contact = contact
            message_list_view = new MessageListView
                model: active_contact.get 'messages'
    """
