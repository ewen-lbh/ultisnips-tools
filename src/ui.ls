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

# Generate snippet and put in to the result <textarea>, only if the result textarea is not focused.
update-result = ->
    if document.focused-element != id \result
        id \result .value = snippet |> generate-snippet
        c snippet
    else
        c 'not updating, focused element is the result.'
update-result() # Initial call

# Binder function
bind-to-element = (element-id, snippet-property = null) ->
    c "binding to #element-id"
    id element-id .add-event-listener \input, ->
        snippet[snippet-property or element-id] = id element-id .value
        update-result()

# Handle priority, name, trigger and context
<[priority name trigger content context]>.for-each (el) -> bind-to-element el

# Handle post-jump
bind-to-element \post-jump \postJump # snippet.post-jump gets mangled to postJump

# Handle flags
ids <[trigger-type--regex trigger-type--text]> .for-each -> it.add-event-listener \change, ->
    snippet.flags.r = id \trigger-type--regex .checked
    update-result()
<[b i A]>.for-each (flag) ->
    id "flag-#flag" .add-event-listener \change, ->
        snippet.flags[flag] = id "flag-#flag" .checked
        update-result()

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
