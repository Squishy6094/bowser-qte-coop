-- name: Bowser Quick Time Event

local configSounds = mod_storage_load_integer("configSounds", 0)

local m = gMarioStates[0] ---@type MarioState
local l = gLakituState

local quickTimeInputs = {
    {func = function (c) return c.buttonPressed & A_BUTTON ~= 0 end, text = "A"},
    {func = function (c) return c.buttonPressed & B_BUTTON ~= 0 end, text = "B"},
    {func = function (c) return c.buttonPressed & Z_TRIG ~= 0 end, text = "Z"},
    {func = function (c) return c.buttonPressed & R_TRIG ~= 0 end, text = "R"},
}
local currQuickTime = {}
local timePerInput = 30

local SOUND_UNLEASHED_FINISHED = audio_sample_load("qte_unleashed_finished.ogg")
local SOUND_UNLEASHED_HIT = audio_sample_load("qte_unleashed_hit.ogg")
local SOUND_UNLEASHED_MISS = audio_sample_load("qte_unleashed_miss.ogg")

local function get_bowser_qte_inputs(o)
    if o.oBehParams2ndByte == 0 then
        return 5, 30
    elseif o.oBehParams2ndByte == 1 then
        return 10, 20
    elseif o.oBehParams2ndByte == 2 then
        if o.oHealth == 3 then
            return 15, 15
        elseif o.oHealth == 2 then
            return 17, 15
        elseif o.oHealth == 1 then
            return 20, 15
        end
    end
end

local function act_hold_bowser_qte(m)
    if not m then return end
    local nearestBomb = cur_obj_nearest_object_with_behavior(get_behavior_from_id(id_bhvBowserBomb))
    if (m.playerIndex ~= 0) then
        if (m.marioBodyState.grabPos ~= GRAB_POS_BOWSER) then
            m.usedObj = cur_obj_nearest_object_with_behavior(get_behavior_from_id(id_bhvBowser));
            m.angleVel.y = 0;
            m.marioBodyState.grabPos = GRAB_POS_BOWSER;
            mario_grab_used_object(m);
            if (m.heldObj ~= nil) then
                queue_rumble_data_mario(m, 5, 80);
                play_character_sound(m, CHAR_SOUND_HRMM);
            else
                set_mario_action(m, ACT_IDLE, 0);
                return 0;
            end
        end
    end

    djui_chat_message_create(tostring(m.usedObj.oHealth))

    -- Initialize Quick Time event
    if m.actionState == 0 then
        currQuickTime = {}
        local inputCount = 1
        inputCount, timePerInput = get_bowser_qte_inputs(m.usedObj)
        for i = 1, inputCount do
            local input = quickTimeInputs[math.random(1, #quickTimeInputs)]
            table.insert(currQuickTime, {
                func = input.func,
                text = input.text,
                hit = false,
                opacity = 255,
            })
        end
        m.actionState = 1
    end

    -- Quick Time Event
    if m.actionState == 1 then
        m.actionTimer = m.actionTimer + 1

        if nearestBomb then
            local bombAngle = atan2s(nearestBomb.oPosZ - m.pos.z, nearestBomb.oPosX - m.pos.x)
            l.focus.x = math.lerp(l.focus.x, nearestBomb.oPosX + sins(bombAngle-0x4000)*1000, 0.1)
            l.focus.y = math.lerp(l.focus.y, nearestBomb.oPosY, 0.1)
            l.focus.z = math.lerp(l.focus.z, nearestBomb.oPosZ + coss(bombAngle-0x4000)*1000, 0.1)

            l.pos.x = math.lerp(l.pos.x, m.pos.x + sins(bombAngle+0x6000)*800, 0.1)
            l.pos.y = math.lerp(l.pos.y, m.pos.y + 100, 0.1)
            l.pos.z = math.lerp(l.pos.z, m.pos.z + coss(bombAngle+0x6000)*800, 0.1)
        end

        local complete = true
        for inputNum, input in pairs(currQuickTime) do
            if not input.hit then
                if input.func(m.controller) then
                    if configSounds == 0 then
                        play_sound_with_freq_scale(SOUND_MENU_CLICK_CHANGE_VIEW, gGlobalSoundSource, 0.9 + 0.4*(inputNum/#currQuickTime))
                    elseif configSounds == 1 then
                        audio_sample_play(SOUND_UNLEASHED_HIT, gGlobalSoundSource, 1)
                    end
                    input.hit = true
                else
                    for _, input in pairs(quickTimeInputs) do
                        if input.func(m.controller) then
                            if configSounds == 0 then
                                play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
                            elseif configSounds == 1 then
                                audio_sample_stop(SOUND_UNLEASHED_MISS)
                                audio_sample_play(SOUND_UNLEASHED_MISS, gGlobalSoundSource, 1)
                            end
                            m.actionTimer = m.actionTimer + timePerInput*0.5
                        end
                    end
                end
                complete = false
                break
            end
        end
        if complete then
            if configSounds == 0 then
                play_sound(SOUND_GENERAL2_RIGHT_ANSWER, gGlobalSoundSource)
            elseif configSounds == 1 then
                audio_sample_play(SOUND_UNLEASHED_FINISHED, gGlobalSoundSource, 1)
            end
            m.actionState = 3
        elseif m.actionTimer > #currQuickTime * timePerInput then
            m.actionState = 2
        end
    end

    if (m.playerIndex == 0 and (m.actionState == 2 or m.actionState == 3 or not nearestBomb)) then
        if not nearestBomb then
            play_character_sound(m, CHAR_SOUND_MAMA_MIA);
            return set_mario_action(m, ACT_RELEASING_BOWSER, 0);
        else
            local bombAngle = atan2s(nearestBomb.oPosZ - m.pos.z, nearestBomb.oPosX - m.pos.x) + (m.actionState == 2 and 0x2000 or 0)
            if m.angleVel.y >= 0xFFF and math.abs(math.s16(m.faceAngle.y - bombAngle)) < 0x800 then
                if m.actionState == 2 then
                    play_character_sound(m, CHAR_SOUND_WHOA);
                else
                    play_character_sound(m, CHAR_SOUND_SO_LONGA_BOWSER);
                end
                return set_mario_action(m, ACT_RELEASING_BOWSER, 0);
            end
        end
    end

    --[[
    if (m.playerIndex == 0 and m.angleVel.y == 0) then
        if (m.actionTimer > 120) then
            return set_mario_action(m, ACT_RELEASING_BOWSER, 1);
        end

        set_character_animation(m, CHAR_ANIM_HOLDING_BOWSER);
    else
        m.actionTimer = 0;
        set_character_animation(m, CHAR_ANIM_SWINGING_BOWSER);
    end
    ]]

    --if (m.intendedMag > 20.0) then
        if (m.actionArg == 0) then
            m.actionArg = 1;
            m.twirlYaw = m.intendedYaw;
        else
            -- spin = acceleration
            local spin = 0x30--math.s16(m.intendedYaw - m.twirlYaw) / 0x80;

            if (spin < -0x80) then
                spin = -0x80;
            end
            if (spin > 0x80) then
                spin = 0x80;
            end

            m.twirlYaw = m.intendedYaw;
            m.angleVel.y = m.angleVel.y + spin;

            if (m.angleVel.y > 0x1000) then
                m.angleVel.y = 0x1000;
            end
            if (m.angleVel.y < -0x1000) then
                m.angleVel.y = -0x1000;
            end
        end
    --else
    --    m.actionArg = 0;
    --    m.angleVel.y = approach_s32(m.angleVel.y, 0, 64, 64);
    --end

    -- spin = starting yaw
    spin = m.faceAngle.y;
    m.faceAngle.y = m.angleVel.y + spin;

    -- play sound on overflow
    if (m.angleVel.y <= -0x100 and spin < m.faceAngle.y) then
        queue_rumble_data_mario(m, 4, 20);
        play_sound(SOUND_OBJ_BOWSER_SPINNING, m.marioObj.header.gfx.cameraToObject);
    end
    if (m.angleVel.y >= 0x100 and spin > m.faceAngle.y) then
        queue_rumble_data_mario(m, 4, 20);
        play_sound(SOUND_OBJ_BOWSER_SPINNING, m.marioObj.header.gfx.cameraToObject);
    end

    stationary_ground_step(m);
    if (m.angleVel.y >= 0) then
        m.marioObj.header.gfx.angle.x = -m.angleVel.y;
    else
        m.marioObj.header.gfx.angle.x = m.angleVel.y;
    end

    return 0;
end

hook_mario_action(ACT_HOLDING_BOWSER, act_hold_bowser_qte)

local wasQuickTime = false
local xPosLerp = 0
local greyLerp = 1
local barLerp = 0
local timerLerp = 0
local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_N64)
    local sW = djui_hud_get_screen_width() + 1
    local sH = djui_hud_get_screen_height()

    if m.action == ACT_HOLDING_BOWSER or m.action == ACT_RELEASING_BOWSER then
        local timer = (m.action == ACT_HOLDING_BOWSER and m.actionState == 1) and m.actionTimer/(#currQuickTime * timePerInput) or 0
        wasQuickTime = true

        djui_hud_set_color(0, 0, 0, 255)
        djui_hud_render_rect(0, 0, sW, barLerp - 1)
        djui_hud_render_rect(0, sH - barLerp, sW, barLerp + 1)

        if m.action == ACT_HOLDING_BOWSER and m.actionState == 1 then
            greyLerp = math.lerp(greyLerp, 0.2 + 0.4*timer, 0.1)
            barLerp = math.lerp(barLerp, 35, 0.1)
            timerLerp = math.floor(math.lerp(timerLerp, (#currQuickTime * timePerInput) - m.actionTimer, m.actionTimer > 1 and 0.5 or 1))
        else
            greyLerp = math.lerp(greyLerp, 1, 0.1)
            barLerp = math.lerp(barLerp, -30, 0.1)
            timerLerp = math.floor(math.lerp(timerLerp, 0, 0.1))
        end

        djui_hud_set_font(FONT_HUD)
        local xPosTarget = 0
        for inputNum, input in pairs(currQuickTime) do
            if input.hit then
                xPosTarget = xPosTarget + 18
                input.opacity = math.lerp(input.opacity, 0, 0.2)
            end
            djui_hud_set_color(255, 255, 255, input.opacity)
            djui_hud_print_text(input.text, 24 + math.max((inputNum - 1)*18 - xPosLerp, 0), sH - (barLerp + 21) - (1 - input.opacity/255)*50, 1, 1)
        end
        if m.actionTimer > 1 then
            xPosLerp = math.lerp(xPosLerp, xPosTarget, 0.2)
        end

        local timerSecs = math.floor(timerLerp  / 30);
        local timerFracSecs = math.floor(((timerLerp - (timerSecs * 30)) & 0xFFFF) / 3);
        djui_hud_set_color(255, 255, 255, 255)
        local x = sW - 37
        djui_hud_print_text(tostring(timerFracSecs), x, barLerp + 5, 1, 1)
        djui_hud_print_text('"', x - 9, barLerp - 2, 1, 1)
        x = sW - 71
        djui_hud_print_text(string.format("%02d", timerSecs), x, barLerp + 5, 1, 1)
        x = x - 15 - djui_hud_measure_text("TIME")
        djui_hud_print_text("TIME", x, barLerp + 5, 1, 1)
        
        set_shader_flag_enabled(SHADER_FLAG_SATURATION, true)
        set_shader_flag_value(SHADER_FLAG_SATURATION, greyLerp)

        camera_freeze()
    elseif wasQuickTime then
        set_shader_flag_enabled(SHADER_FLAG_SATURATION, false)
        camera_unfreeze()
        xPosLerp = 0
        greyLerp = 1
        barLerp = -30
    end
end

local function update()
    if gMarioStates[0].controller.buttonPressed & U_JPAD ~= 0 then
        warp_to_level(LEVEL_BOWSER_3, 1, 0)
    end
    if gMarioStates[0].controller.buttonPressed & L_JPAD ~= 0 then
        warp_to_level(LEVEL_BOWSER_1, 1, 0)
    end
    if gMarioStates[0].controller.buttonPressed & R_JPAD ~= 0 then
        warp_to_level(LEVEL_BOWSER_2, 1, 0)
    end
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_MODS_LOADED, function()
    hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
end)

---@param string string
--- Splits a string into a table by spaces
local function string_split(string, splitAt)
    if splitAt == nil then
        splitAt = " "
    end
    local result = {}
    for match in string:gmatch(string.format("[^%s]+", splitAt)) do
        table.insert(result, match)
    end
    return result
end

local function chat_command(msg)
    msg = string.lower(msg)
    msgSplit = string_split(msg)
    if msgSplit[1] == "sounds" then
        if msgSplit[2] == "sm64" then
            configSounds = 0
            mod_storage_save_integer("configSounds", configSounds)
            djui_chat_message_create("Quick Time Event Sounds set to \\#ffff33\\Super Mario 64")
            return true
        elseif msgSplit[2] == "unleashed" then
            configSounds = 1
            mod_storage_save_integer("configSounds", configSounds)
            djui_chat_message_create("Quick Time Event Sounds set to \\#ffff33\\Sonic Unleashed")
            return true
        end

        djui_chat_message_create("Inputs must be 'sm64' or 'unleashed'")
        return true
    end

    djui_chat_message_create("Quick Time Event Commands:"..
    "\n\\#ffff33\\/qte sounds\\#ffffff\\ - Toggles which sounds to use during Quick Time Event")
    return true
end

hook_chat_command("qte", "- Configure Quick Time Event Settings", chat_command)