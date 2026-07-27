-- sv_arteria_roll.lua
-- When org.arteria == 1:
--   Player is forced into ragdoll (hg.Fake) and cannot stand back up
--   Voice chat is silenced for the duration
--   Hands fly to the neck wound position (mirroring the neckslit logic in sv_control)
--   Spine rolls left/right using phase-based shadow control (same method as neckslit rolling)
--
-- Place in the fake/ folder alongside sv_control.lua

local ROLL_SPEED     = 1.5   -- phase cycles per second (matches neckslit's 1.5)
local ROLL_FORCE     = 490   -- angular force for spine roll (same as fire roll in sv_control)
local ROLL_DAMP      = 90
local ROLL_DEGREES   = 20    -- degrees added per frame to spine angle (same as fire roll)
local HAND_SPEED_MAX = 100   -- max speed driving hands to neck wound
local HAND_DAMP      = 20

local KICK_SPEED      = 2.2   -- phase cycles per second, deliberately not synced with ROLL_SPEED
local KICK_FORCE      = 420
local KICK_DAMP       = 80
local KICK_DEGREES    = 25    -- degrees added to thigh pitch during a kick

-- Tracks which players are currently locked down by an arterial bleed
-- Key: player entity, Value: true while arteria == 1 and alive
local arteriaLocked = {}

local function neckOpen(org)
	return org and (org.arteria == 1 or org.jugular == 1)
end

-- ── Voice mute ───────────────────────────────────────────────────────────────
-- Returning false from PlayerCanHearPlayersVoice prevents all other players
-- from receiving voice from the locked player.
hook.Add("PlayerCanHearPlayersVoice", "ArteriaVoiceMute", function(listener, talker)
	if arteriaLocked[talker] then
		return false, false
	end
end)

-- ── Cleanup on disconnect ─────────────────────────────────────────────────────
hook.Add("PlayerDisconnected", "ArteriaLockCleanup", function(ply)
	arteriaLocked[ply] = nil
	ply.arteriaLocked  = nil
end)

-- ── Main Think loop ───────────────────────────────────────────────────────────
hook.Add("Think", "ArteriaRoll", function()
	for _, ply in player.Iterator() do
		local org = ply.organism

		-- ── State management (runs regardless of ragdoll validity) ────────────
		if neckOpen(org) and ply:Alive() then

			-- First frame of arteria: knock the player down
			if not arteriaLocked[ply] then
				arteriaLocked[ply] = true
				ply.arteriaLocked  = true
				if not IsValid(ply.FakeRagdoll) then
					hg.Fake(ply)
				end
			end

			-- Every frame: if they somehow stood up (e.g. script re-raised them),
			-- force them back down immediately.
			if not IsValid(ply.FakeRagdoll) then
				hg.Fake(ply)
			end

		else
			-- Arteria ended (healed, died, etc.) — lift all restrictions
			if arteriaLocked[ply] then
				arteriaLocked[ply] = nil
				ply.arteriaLocked  = nil
			end
		end

		-- ── Ragdoll physics / animation (requires a valid ragdoll) ───────────
		local ragdoll = hg.ragdollFake[ply]
		if not IsValid(ragdoll) then continue end
		if not org or not neckOpen(org) then continue end
		if not ply:Alive() then continue end
		if org.consciousness < 0.4 then continue end

		-- ── Find the arterial neck wound ─────────────────────────────────────
		local neckwound
		if org.arterialwounds then
			for i, wound in pairs(org.arterialwounds) do
				if wound[7] == "arteria" then
					neckwound = wound
					break
				elseif wound[7] == "jugular" and not neckwound then
					neckwound = wound
				end
			end
		end

		-- ── Hands to neck wound ───────────────────────────────────────────────
		-- Uses same pattern as the neckslit block in sv_control:
		-- drive hands to the world position of the wound on its bone.
		if neckwound and ragdoll:LookupBone(neckwound[4]) then
			local bone = ragdoll:LookupBone(neckwound[4])
			local neckpos, neckang = ragdoll:GetBonePosition(bone)
			if neckpos and neckang then
				local right    = neckang:Right()
				local fwd      = neckang:Forward()
				local up       = neckang:Up()
				local leftpos  = neckpos + right * -3 + fwd * 2 + up * -1
				local rightpos = neckpos + right *  3 + fwd * 2 + up * -1
				hg.ShadowControl(ragdoll, 5,  0.001, nil, nil, nil, leftpos,  HAND_SPEED_MAX, HAND_DAMP)
				hg.ShadowControl(ragdoll, 7,  0.001, nil, nil, nil, rightpos, HAND_SPEED_MAX, HAND_DAMP)
				hg.ShadowControl(ragdoll, 10, 0.001, nil, nil, nil, neckpos,  50, 10)
			end
		else
			-- Fallback: no wound data yet — aim hands at the head bone
			local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
			if headBone then
				local headPos = ragdoll:GetBonePosition(headBone)
				if headPos then
					local neckPosL = headPos + ragdoll:GetAngles():Right() *  3 - Vector(0, 0, 4)
					local neckPosR = headPos + ragdoll:GetAngles():Right() * -3 - Vector(0, 0, 4)
					hg.ShadowControl(ragdoll, 5, 0.001, nil, nil, nil, neckPosL, HAND_SPEED_MAX, HAND_DAMP)
					hg.ShadowControl(ragdoll, 7, 0.001, nil, nil, nil, neckPosR, HAND_SPEED_MAX, HAND_DAMP)
				end
			end
		end

		-- ── Phase-based spine roll ────────────────────────────────────────────
		-- Mirrors the neckslit keyLeft/keyRight phase logic in sv_control exactly.
		-- Phase 0-1  → roll left  (spine angle[3] -= 20)
		-- Phase 1-2  → neutral pause
		-- Phase 2-3  → roll right (spine angle[3] += 20)
		-- Phase 3-4  → neutral pause
		local phase = (CurTime() * ROLL_SPEED) % 4
		local spine = ragdoll:GetPhysicsObjectNum(hg.realPhysNum(ragdoll, 1))
		if IsValid(spine) then
			local angle = spine:GetAngles()
			if phase < 1 then
				-- roll left
				angle[3] = angle[3] - ROLL_DEGREES
				hg.ShadowControl(ragdoll, 1, 0.001, angle, ROLL_FORCE, ROLL_DAMP)
			elseif phase >= 2 and phase < 3 then
				-- roll right
				angle[3] = angle[3] + ROLL_DEGREES
				hg.ShadowControl(ragdoll, 1, 0.001, angle, ROLL_FORCE, ROLL_DAMP)
			end
			-- phases 1-2 and 3-4 are intentional pauses (no shadow control = physics settles)
		end

		-- ── Phase-based leg kick ──────────────────────────────────────────────
		-- Off-cycle from the spine roll on purpose (different speed constant) so
		-- the convulsion doesn't look mechanically synced. Left and right legs
		-- are half a phase apart so they alternate rather than kick together.
		-- Resolved dynamically via TranslateBoneToPhysBone instead of a hardcoded
		-- physics-object index, since leg indices aren't established elsewhere
		-- in this codebase the way spine(1)/hands(5,7,10) are.
		local kickPhase = (CurTime() * KICK_SPEED) % 2
		local legs = {
			{bone = "ValveBiped.Bip01_L_Thigh", offset = 0},
			{bone = "ValveBiped.Bip01_R_Thigh", offset = 1},
		}
		for _, leg in ipairs(legs) do
			local boneId = ragdoll:LookupBone(leg.bone)
			if not boneId then continue end
			local physId = ragdoll:TranslateBoneToPhysBone(boneId)
			local physObj = ragdoll:GetPhysicsObjectNum(physId)
			if not IsValid(physObj) then continue end

			local p = (kickPhase + leg.offset) % 2
			local angle = physObj:GetAngles()
			if p < 0.5 then
				angle[2] = angle[2] - KICK_DEGREES
				hg.ShadowControl(ragdoll, physId, 0.001, angle, KICK_FORCE, KICK_DAMP)
			elseif p >= 1 and p < 1.5 then
				angle[2] = angle[2] + KICK_DEGREES
				hg.ShadowControl(ragdoll, physId, 0.001, angle, KICK_FORCE, KICK_DAMP)
			end
		end
	end
end)