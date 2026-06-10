--- UI navigation state helpers
--
-- Tracks navigation groups and items on top of the engine navigation system.
-- The engine still owns actual focus movement. This module observes focus via
-- `UiIsComponentInFocus(...)`, remembers per-group item history, and restores
-- focus when re-entering managed groups.
--
-- Core responsibilities:
--
-- * Define managed navigation groups and items
-- * Remember the last focused item per group
-- * Support a default item per group
-- * Restore group focus when the active managed group changes
-- * Allow groups to lock or temporarily disable managed navigation
--
-- Execution context:
--
-- * Client-side only
-- * `navigationBeginFrame()` is optional bookkeeping and does not call `Ui...`
-- * `UiForceFocus(...)` is only applied from `navigationBeginGroup(...)`

_navigation = {
    newFrame = true,
    frameInitialized = false,
    groupStack = {},
    groups = {},
    frame = nil,
    activeHistory = { nil, nil },
    lockedGroupId = nil,
    pendingFocusGroupId = nil,
    pendingFocusItemId = nil,
    pendingFocusApplied = false,
}

--- Mark the start of a new frame for managed navigation (client).
--
-- This function is optional. It only advances internal bookkeeping and does
-- not call any `Ui...` functions, which makes it safe to call outside draw.
-- If it is not called explicitly, the first `navigationBeginGroup(...)` call
-- of the frame will start the frame lazily.
function navigationBeginFrame()
    _navigation.newFrame = true
    _navigation.frameInitialized = false
end

--- Begin a managed navigation group (client).
--
-- Wraps an engine navigation group and registers it with the Lua navigation
-- model for the current frame. If this group is the pending restore target,
-- focus restoration is applied here.
--
-- @param[type=string] name Stable group identifier.
-- @param[opt,type=boolean] lockNavigation When `true`, this group claims
--   managed navigation after frame resolution. Suppression of other groups is
--   applied on subsequent frames, not retroactively within the current draw
--   order, which avoids order-dependent locking behavior inside a single frame.
-- @param[opt,type=boolean] navigationDisabled When `true`, the group is drawn
--   but excluded from managed navigation state for the current frame.
function navigationBeginGroup(name, lockNavigation, navigationDisabled)
    _ensureFrameStarted()
    _applyPendingFocus(name, navigationDisabled)

    UiPush()

    local navId = UiNavGroupBegin(name)

    local group = _navigation.groups[name]
    if not group then
        group = {
            name = name,
            navId = navId,
            lastFocusedItem = nil,
            defaultItem = nil,
            items = {},
        }
        _navigation.groups[name] = group
    end

    group.navId = navId
    group.items = {}
    group.navigationDisabled = navigationDisabled or false

    if not group.navigationDisabled then
        _navigation.frame.seenGroups[name] = true
        if lockNavigation then
            _navigation.frame.lockedGroupId = name
        end
    end

    table.insert(_navigation.groupStack, group)

    if not group.navigationDisabled and _navigation.lockedGroupId ~= nil and name ~= _navigation.lockedGroupId then
        UiDisableInput()
    end
end

--- End the current managed navigation group (client).
--
-- Closes the engine group wrapper and records whether the group itself was the
-- active focused group during this frame.
function navigationEndGroup()
    local group = _currentGroup()

    UiNavGroupEnd()
    if not group.navigationDisabled and UiIsComponentInFocus(group.navId) then
        _navigation.frame.activeGroupId = group.name
    end

    UiPop()

    table.remove(_navigation.groupStack)
end

--- Register an item in the current managed navigation group (client).
--
-- Items are registered in draw order. Group-level helpers such as
-- `navigationMakeLastItemDefault()` and `navigationMakeLastItemFocused()` act
-- on the most recently registered item.
--
-- @param item Engine navigation id for the item.
function navigationAddItem(item)
    local parent = _currentGroup()
    if parent and not parent.navigationDisabled then
        table.insert(parent.items, item)
    end
end

--- Mark the most recently added item as the group's default item (client).
--
-- The default item is used when re-entering a managed group that has no
-- remembered focused item yet.
function navigationMakeLastItemDefault()
    local parent = _currentGroup()
    if parent and not parent.navigationDisabled and #parent.items > 0 then
        parent.defaultItem = parent.items[#parent.items]
    end
end

--- Mark the most recently added item as the group's currently focused item (client).
--
-- This should be called when the item is considered focused by the engine or
-- when mouse hover should count as focus inside the Lua navigation model.
function navigationMakeLastItemFocused()
    local parent = _currentGroup()
    if parent and not parent.navigationDisabled and #parent.items > 0 then
        local item = parent.items[#parent.items]
        _navigation.frame.focusedItemByGroup[parent.name] = item
        _navigation.frame.focusedItem = item
    end
end

--- Check whether an item is the currently focused managed item (client).
--
-- @param item Engine navigation id for the item.
-- @return[type=boolean] `true` if this item is the current managed focused item.
function navigationIsItemFocused(item)
    return _navigation.frame and _navigation.frame.focusedItem == item
end

-- Internal functions

function _createFrameSnapshot()
    return {
        seenGroups = {},
        activeGroupId = nil,
        focusedItemByGroup = {},
        focusedItem = nil,
        lockedGroupId = nil,
    }
end

function _currentGroup()
    return _navigation.groupStack[#_navigation.groupStack]
end

function _resolveFocusItem(groupId)
    if not groupId then
        return nil
    end

    local group = _navigation.groups[groupId]
    if not group then
        return nil
    end

    return group.lastFocusedItem or group.defaultItem
end

function _pushActiveHistory(groupId)
    if not groupId or _navigation.activeHistory[1] == groupId then
        return
    end

    _navigation.activeHistory[2] = _navigation.activeHistory[1]
    _navigation.activeHistory[1] = groupId
end

function _resolveActiveGroup(frame)
    if frame.lockedGroupId and frame.seenGroups[frame.lockedGroupId] then
        return frame.lockedGroupId
    end

    if frame.activeGroupId then
        return frame.activeGroupId
    end

    local previousActive = _navigation.activeHistory[1]
    if previousActive and frame.seenGroups[previousActive] then
        return previousActive
    end

    local olderActive = _navigation.activeHistory[2]
    if olderActive and frame.seenGroups[olderActive] then
        return olderActive
    end

    return nil
end

function _finalizeCompletedFrame()
    local frame = _navigation.frame
    if not frame then
        return
    end

    local resolvedActiveGroupId = _resolveActiveGroup(frame)
    local resolvedFocusItemId = _resolveFocusItem(resolvedActiveGroupId)
    local observedFocusItemId = resolvedActiveGroupId and frame.focusedItemByGroup[resolvedActiveGroupId] or nil
    local previousActiveGroupId = _navigation.activeHistory[1]
    local shouldForceFocus = false

    if resolvedActiveGroupId then
        if previousActiveGroupId ~= resolvedActiveGroupId and resolvedFocusItemId and resolvedFocusItemId ~= observedFocusItemId then
            shouldForceFocus = true
        end
    end

    _navigation.pendingFocusGroupId = resolvedActiveGroupId
    _navigation.pendingFocusItemId = shouldForceFocus and resolvedFocusItemId or nil
    _navigation.lockedGroupId = frame.lockedGroupId

    _pushActiveHistory(resolvedActiveGroupId)

    for groupId, itemId in pairs(frame.focusedItemByGroup) do
        local group = _navigation.groups[groupId]
        if group then
            group.lastFocusedItem = itemId
        end
    end
end

function _beginManagedFrame()
    _finalizeCompletedFrame()

    _navigation.groupStack = {}
    _navigation.frame = _createFrameSnapshot()
    _navigation.frameInitialized = true
    _navigation.pendingFocusApplied = false
    _navigation.newFrame = false

    for _, group in pairs(_navigation.groups) do
        group.items = {}
    end
end

function _ensureFrameStarted()
    if _navigation.newFrame or not _navigation.frameInitialized then
        _beginManagedFrame()
    end
end

function _applyPendingFocus(groupName, navigationDisabled)
    if _navigation.pendingFocusApplied or not _navigation.pendingFocusItemId then
        return
    end

    if groupName ~= _navigation.pendingFocusGroupId then
        return
    end

    if navigationDisabled then
        return
    end

    UiForceFocus(_navigation.pendingFocusItemId)
    _navigation.pendingFocusApplied = true
end
