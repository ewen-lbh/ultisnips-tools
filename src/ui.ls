c = console.log

/*
Tab handling
*/
document.query-selector-all \._tabbed .for-each (tabbed-content) ->
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
            
        
