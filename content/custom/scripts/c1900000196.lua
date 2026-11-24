-- Pinsir
-- This card's ATK/DEF cannot be changed by your opponent's card effects.
-- If this card attacks a monster, that monster's effects are negated until the end of the Damage Step.
-- Negate the effects of monsters destroyed by battle with Insect monsters you control.
-- (Done as: unaffected by your opponent's effects that change ATK/DEF.)
local s,id=GetID()
local STATCODES={[EFFECT_UPDATE_ATTACK]=true,[EFFECT_UPDATE_DEFENSE]=true,[EFFECT_SET_ATTACK]=true,[EFFECT_SET_DEFENSE]=true,
	[EFFECT_SET_ATTACK_FINAL]=true,[EFFECT_SET_DEFENSE_FINAL]=true,[EFFECT_SET_BASE_ATTACK]=true,[EFFECT_SET_BASE_DEFENSE]=true}
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_IMMUNE_EFFECT)
	e1:SetValue(function(e,te)
		return te:GetOwnerPlayer()~=e:GetHandlerPlayer()
			and (STATCODES[te:GetCode()] or te:IsHasCategory(CATEGORY_ATKCHANGE|CATEGORY_DEFCHANGE))
	end)
	c:RegisterEffect(e1)
	-- The monster it attacks has its effects negated (during the battle)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_DISABLE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetTargetRange(0,LOCATION_MZONE)
	e2:SetCondition(function(e) return Duel.GetAttacker()==e:GetHandler() end)
	e2:SetTarget(function(e,tc) return tc==Duel.GetAttackTarget() end)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EFFECT_DISABLE_EFFECT)
	c:RegisterEffect(e3)
	-- Monsters destroyed by battle with your Insects: negated (like Primeape)
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_BATTLED)
	e4:SetRange(LOCATION_MZONE)
	e4:SetOperation(function(e,tp)
		local a,d=Duel.GetAttacker(),Duel.GetAttackTarget()
		if not d then return end
		for _,pair in ipairs({{a,d},{d,a}}) do
			local mine,other=pair[1],pair[2]
			if mine:IsControler(tp) and mine:IsRace(RACE_INSECT) and other:IsStatus(STATUS_BATTLE_DESTROYED) then
				for _,code in ipairs({EFFECT_DISABLE,EFFECT_DISABLE_EFFECT}) do
					local ef=Effect.CreateEffect(e:GetHandler())
					ef:SetType(EFFECT_TYPE_SINGLE)
					ef:SetCode(code)
					ef:SetReset(RESET_EVENT|RESETS_STANDARD_EXC_GRAVE)
					other:RegisterEffect(ef)
				end
			end
		end
	end)
	c:RegisterEffect(e4)
end
