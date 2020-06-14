# Shortcuts
c = console.log
el = document.query-selector.bind document
els = document.query-selector-all.bind document
id = document.get-element-by-id.bind document
ids = -> it.map -> id(it)

/*
Tab handling
*/
els \._tabbed .for-each (tabbed-content) ->
    { current-tab-controller } = tabbed-content.dataset
    # Store the currently active tab
    active-tab = ''
    # Get all radio buttons with name corresponding to the current-tab-controller
    tabbed-content.query-selector-all "input[type=radio][name='#current-tab-controller']" .forEach (tab-selector) ->
        # Define the function
        set-active-tab = ->
            if tab-selector.checked
                active-tab = tab-selector.value

                # Get all the tab contents
                tabbed-content.query-selector-all '[data-tab]' .for-each (tab-content) ->
                    if tab-content.dataset.tab == active-tab
                        tab-content.set-attribute \data-tab-active, ''
                    else
                        tab-content.remove-attribute \data-tab-active
        # The button's value corresponds to a [data-tab] attribute value
        tab-selector.add-event-listener \change, set-active-tab
        # Initial run
        set-active-tab()
            
        
/*
Snippet generation
*/

# This object contains the current snippet (initialized to an empty one)
snippet = 
    priority: null
    post-jump: null
    context: null
    trigger: ''
    name: ''
    flags:
        b: false
        i: false
        w: false
        r: false
        t: false
        s: false
        m: false
        e: false
        A: false
    content: ''

update-result = ->
    snippet := 
        priority: (id \priority .value) or null
        post-jump: (id \post-jump .value) or null
        context: (id \context .value) or null
        trigger: id \trigger .value
        name: id \name .value
        flags:
            b: id \flag-b .checked
            i: id \flag-i .checked
            w: snippet.flags.w  # Don't always set to false, as the Analyze function could have set it to true
            r: id \trigger-type--regex .checked
            t: snippet.flags.t  # Don't always set to false, as the Analyze function could have set it to true
            s: snippet.flags.s  # Don't always set to false, as the Analyze function could have set it to true
            m: snippet.flags.m  # Don't always set to false, as the Analyze function could have set it to true
            e: snippet.flags.e  # Don't always set to false, as the Analyze function could have set it to true
            A: id \flag-A .checked
        content: id \content .value
    
    # Generate snippet and put in to the result <textarea>, 
    # only if the result textarea is not focused.
    if document.focused-element != id \result
        console.group 'Generating snippet'
        c snippet
        console.group-end!
        id \result .value = snippet |> generate-snippet

listen-to-all = ->
    # Gather elements to listen to
    listen-to = ids <[
        priority
        name
        trigger
        content
        context
        post-jump
        trigger-type--regex
        trigger-type--text
        flag-i
        flag-b
        flag-A
        insert-tabstop
        insert-code-python
        insert-code-vimscript
        insert-code-shell
        insert-tabstop-reference
        insert-trigger-regex-group-reference  
    ]>
    
    # Listen to all of them
    console.group 'Adding hooks to inputs'
    listen-to.for-each ->
        # Determinate the event name
        if it.tag-name is \BUTTON
            event-name = \click
        else if it.tag-name is \INPUT
            if it.get-attribute(\type) in <[checkbox radio]>
                event-name = \change
            else
                event-name = \input
        else if it.tag-name is \TEXTAREA
            event-name = \input
        
        c "##{it.id} -> #event-name"
        it.add-event-listener event-name, update-result
    console.group-end!

update-result!
listen-to-all!

/*
Snippet parsing
*/

update-snippet-object = ->
    bind-to-snippet-property = (element-id, snippet-property = null) ->
        id element-id .value = snippet[snippet-property or element-id]

    # Handle priority, name, trigger and context
    <[priority name trigger content context]>.for-each -> bind-to-snippet-property(it)
    bind-to-snippet-property 'post-jump', 'postJump'
    
    id \trigger-type--regex .checked = snippet.flags.r
    id \trigger-type--text .checked = not snippet.flags.r
    
    <[b i A]>.for-each ->
        id "flag-#it" .checked = snippet.flags[it]

id \analyze-btn .add-event-listener \click, ->
    snippet <<< (id \result .value |> extract-snippet)
    update-snippet-object()

/*
Tab stop/code insertion
*/

insert-at-cursor = (text) ->
    textarea = id \content
    if document.selection
        textarea.focus!
        sel = document.selection.create-range!
        sel.text = text
    else
        if textarea.selection-start or textarea.selection-start is '0'
            start-pos = textarea.selection-start
            end-pos = textarea.selection-end
            textarea.value = (textarea.value.substring 0, start-pos) + text + textarea.value.substring end-pos, textarea.value.length
        else
            textarea.value += text
    update-result!
    textarea.focus!

id \insert-tabstop .add-event-listener \click, ->
    it.prevent-default!
    generate-tabstop (
        position: id \tabstop-position .value |> parse-int
        default-value: if id \tabstop-type--default .checked 
            then id \tabstop-default-text .value
            else null
        substitution: if id \tabstop-type--substitution .checked
            then <[find replace]>.map -> id "tabstop-substitution-#it" .value
            else null
    ) |> insert-at-cursor
    false # To prevent submitting the form

/*
Check radio button when clicked on relevant fields
*/

els '[id^=tabstop-substitution]' .for-each -> it.add-event-listener \focus, ->
    id \tabstop-type--substitution .click!
    
id \tabstop-default-text .add-event-listener \focus, ->
    id \tabstop-type--default .click!

/*
Disable inputs not relevant to currently-selected tabstop type
*/

disable-other-inputs = ->
    content-to-toggle = id \tabstop-type--default 
        .parent-element
        .parent-element
        .query-selector \._toggled
    
    if id \tabstop-type--default .checked
        content-to-toggle.class-list.remove \_disabled
    else
        content-to-toggle.class-list.add \_disabled
    
    content-to-toggle = id \tabstop-type--substitution 
        .parent-element
        .parent-element
        .query-selector \._toggled
    
    if id \tabstop-type--substitution .checked
        content-to-toggle.class-list.remove \_disabled
    else
        content-to-toggle.class-list.add \_disabled

els '[id^=tabstop-type--]' .for-each -> it.add-event-listener \change, disable-other-inputs
# initial run
disable-other-inputs()

/*
Disable insert tabstop button if the tabstop position is empty
*/
disable-button = (element-id) ->
    button = id element-id
    # Get the explanation
    why-is-it-disabled = button.dataset.why-disabled
    # Add disabled attribute
    button.set-attribute \disabled, ''
    # Add title, if any
    if why-is-it-disabled
        button.set-attribute \title, why-is-it-disabled
    
enable-button = (element-id) ->
    button = id element-id
    # Remove disabled attribute
    button.remove-attribute \disabled
    # Remove title
    button.remove-attribute \title

disable-insert-tabstop-button = ->
    # c \tabstop-position \value id \tabstop-position .value
    if not id \tabstop-position .value
        disable-button \insert-tabstop
    else
        enable-button \insert-tabstop

id \tabstop-position .add-event-listener \input, disable-insert-tabstop-button
disable-insert-tabstop-button!

/*
Insert code
*/

els '[id^=insert-code-]' .for-each -> it.add-event-listener \click, ->
    generate-code-embed(
        language: it.target.id.replace \insert-code-, ''
        content: ''
    ) |> insert-at-cursor
    snippet.content = id \content .value

/*
Insert tabstop reference
*/

id \insert-tabstop-reference .add-event-listener \click, ->
    if id \tabstop-reference-position .value
        generate-tabstop-reference(
            language: \python
            position: id \tabstop-reference-position .value |> Number
        ) |> insert-at-cursor
        snippet.content = id \content .value

/*
Insert trigger regex group reference
*/

id \insert-trigger-regex-group-reference .add-event-listener \click, ->
    if id \trigger-regex-group-reference-index .value
        generate-trigger-regex-group-reference(
            language: \python
            position: id \trigger-regex-group-reference-index .value |> Number
        ) |> insert-at-cursor
        snippet.content = id \content .value

/*
Disable Insert trigger regex group reference button when trigger is not regex
*/

disable-insert-trigger-regex-group-button = ->
    if id \trigger-type--regex .checked
        enable-button \insert-trigger-regex-group-reference
    else
        disable-button \insert-trigger-regex-group-reference

els '[id^=trigger-type--]' .for-each -> 
    it.add-event-listener \change, disable-insert-trigger-regex-group-button
disable-insert-trigger-regex-group-button! # initial run

/*
Copy to clipboard button
*/
new ClipboardJS '#copy-result'

/*
Make "Acess on the <input type=number>th <Tab> press"'s "th" reactive
*/
els '.ordinal[data-source]' .for-each ->
    target-element = it
    source-element = el it.dataset.source
    source-element.add-event-listener \input, ->
        target-element.text-content = ordinal-suffix Number source-element.value

ordinal-suffix = (int) ->
    if 10 < int < 20
        \th
    else
        switch (int |> String).slice -1 |> Number
        | 1 => \st
        | 2 => \nd
        | 3 => \rd
        default \th

/*
Result <textarea> position
*/

els '[name=result-position]' .for-each ->
    it.add-event-listener \change, ->
        val = it.target.value
        if it.target.checked
            id \analyze .dataset.position = val
