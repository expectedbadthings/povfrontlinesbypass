-- Tenacity GUI API v2
-- Small declarative surface used by all shipped Roblox modules.
return function(core)
    assert(type(core) == 'table', 'Tenacity GUI API requires the Tenacity core')

    local api = {
        Version = 2,
        Core = core,
        Categories = {'Combat', 'Movement', 'Render', 'Player', 'Exploit', 'Misc', 'Scripts'}
    }

    local function category(name)
        assert(type(name) == 'string', 'Category must be a string')
        local result = core.Categories[name]
        assert(result, ('Unknown Tenacity category %q'):format(name))
        return result
    end

    local function setting(module, spec)
        assert(type(spec) == 'table', 'Setting specification must be a table')
        local kind = tostring(spec.Type or spec.Kind or ''):lower()
        spec.Type, spec.Kind = nil, nil

        if kind == 'toggle' or kind == 'boolean' then
            return module:CreateToggle(spec)
        elseif kind == 'slider' or kind == 'number' then
            return module:CreateSlider(spec)
        elseif kind == 'range' or kind == 'twoslider' then
            return module:CreateTwoSlider(spec)
        elseif kind == 'dropdown' or kind == 'mode' or kind == 'select' then
            spec.List = spec.List or spec.Values
            spec.Values = nil
            return module:CreateDropdown(spec)
        elseif kind == 'color' or kind == 'colour' then
            return module:CreateColorSlider(spec)
        elseif kind == 'text' or kind == 'textbox' or kind == 'input' then
            return module:CreateTextBox(spec)
        elseif kind == 'list' or kind == 'textlist' then
            return module:CreateTextList(spec)
        elseif kind == 'bind' or kind == 'keybind' then
            return module:CreateBind(spec)
        elseif kind == 'button' or kind == 'action' then
            return module:CreateButton(spec)
        elseif kind == 'font' then
            return module:CreateFont(spec)
        elseif kind == 'targets' then
            return module:CreateTargets(spec)
        end
        error(('Unsupported Tenacity setting type %q'):format(kind), 3)
    end

    local function decorate(module)
        -- Decorate the actual core module rather than wrapping it. This keeps identity,
        -- iteration, saved profiles and module-to-module references completely intact.
        rawset(module, 'Setting', function(self, spec)
            return setting(self, spec)
        end)
        rawset(module, 'ToggleSetting', function(self, name, default, callback)
            return setting(self, {Type='toggle', Name=name, Default=default, Function=callback})
        end)
        rawset(module, 'Slider', function(self, name, min, max, default, callback)
            return setting(self, {Type='slider', Name=name, Min=min, Max=max, Default=default, Function=callback})
        end)
        rawset(module, 'Mode', function(self, name, values, default, callback)
            return setting(self, {Type='dropdown', Name=name, List=values, Default=default, Function=callback})
        end)
        return module
    end

    function api:Module(categoryName, spec)
        assert(type(spec) == 'table' and type(spec.Name) == 'string', 'Tenacity:Module requires a Name')
        return decorate(category(categoryName):CreateModule(spec))
    end

    function api:GetModule(name)
        return core.Modules[name]
    end

    function api:GetCategory(name)
        return category(name)
    end

    function api:Notify(title, message, duration, kind)
        return core:CreateNotification(title, message, duration, kind)
    end

    function api:Theme(name)
        if name == nil then return core.ActiveThemeName end
        if core.GradientTheme and core.GradientTheme.SetValue then core.GradientTheme:SetValue(name) end
        return core.ActiveThemeName
    end

    function api:Open()
        if core.ClickGUI and not core.ClickGUI.Visible and core.GUIBind then core.GUIBind.Triggered:Fire(true) end
    end

    function api:Close()
        if core.ClickGUI and core.ClickGUI.Visible and core.GUIBind then core.GUIBind.Triggered:Fire(true) end
    end

    function api:ToggleGUI()
        if core.GUIBind then core.GUIBind.Triggered:Fire(true) end
    end

    function api:Cleanup(value)
        return core:Clean(value)
    end

    -- Short public entry points on the core. Game files use these instead of reaching
    -- into category renderer objects directly.
    core.Module = function(_, categoryName, spec) return api:Module(categoryName, spec) end
    core.Notify = function(_, ...) return api:Notify(...) end
    core.GetCategory = function(_, name) return api:GetCategory(name) end
    core.GetModule = function(_, name) return api:GetModule(name) end

    return api
end
