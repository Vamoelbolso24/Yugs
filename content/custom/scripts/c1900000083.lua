-- Persian
-- Evolution Summon from "Meowth" (hard once per turn).
-- If this card is Summoned: You can make your opponent discard 1 random card.
-- If this card inflicts battle damage to your opponent: You can draw 1 card.
-- You can only activate each effect of "Persian" once per turn.
--
-- WHAT WAS WRONG (your version), fixed below:
--  1. EFFECT_TYPE_TRIGGER_o  -> must be EFFECT_TYPE_TRIGGER_O (capital O, the letter, not zero).
--     Lua names are case-sensitive: TRIGGER_o doesn't exist, so it was nil and the effect broke.
--  2. There was an extra "end" after s.target. Lua stopped reading the file there, so the
--     whole card had no effects at all (a syntax error breaks every effect of the card).
--  3. The draw effect used aux.Stringid(id,0) (Prompt 1). Prompt 2 is aux.Stringid(id,1).
--  4. "You can only activate each effect once per turn" was missing: SetCountLimit(1,id) for the
--     first effect and SetCountLimit(1,{id,1}) for the second (each needs its own counter).
--  5. The comments at the top were from Arbok (Ekans, -700 ATK).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000082)   -- from Meowth

	local e1=Effect.CreateEffect(c) -- Discard
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_HANDES)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_DELAY)
	e1:SetCountLimit(1,id)
	e1:SetTarget(s.hdtg)
	e1:SetOperation(s.hdop)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e2)
	local e3=e1:Clone()
	e3:SetCode(EVENT_FLIP_SUMMON_SUCCESS)
	c:RegisterEffect(e3)
	--draw
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,1))
	e4:SetCategory(CATEGORY_DRAW)
	e4:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e4:SetCode(EVENT_BATTLE_DAMAGE)
	e4:SetCountLimit(1,{id,1})
	e4:SetCondition(s.condition)
	e4:SetTarget(s.target)
	e4:SetOperation(s.operation)
	c:RegisterEffect(e4)
end
s.listed_names={1900000082}

function s.hdtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetFieldGroupCount(tp,0,LOCATION_HAND)>0 end
	Duel.SetTargetPlayer(tp)
	Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,1-tp,1)
end
function s.hdop(e,tp,eg,ep,ev,re,r,rp)
	local p=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER)
	local g=Duel.GetFieldGroup(p,0,LOCATION_HAND)   -- (p,0,...) = the hand of p's opponent
	if #g>0 then
		local sg=g:RandomSelect(p,1)
		Duel.SendtoGrave(sg,REASON_EFFECT+REASON_DISCARD)
	end
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return ep~=tp      -- ep = the player who took the damage
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
	Duel.SetTargetPlayer(tp)
	Duel.SetTargetParam(1)
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM)
	Duel.Draw(p,d,REASON_EFFECT)
end
