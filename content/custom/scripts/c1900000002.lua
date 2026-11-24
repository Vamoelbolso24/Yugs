-- Bulbasaur
-- "You can inflict 500 damage to your opponent. You can only use this effect of "Bulbasaur" once per turn."
-- PATTERN: a monster's "You can ..." effect used in your Main Phase = EFFECT_TYPE_IGNITION.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))      -- Prompt 1: "Inflict 500 damage"
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_IGNITION)           -- activated by you during your Main Phase
	e1:SetRange(LOCATION_MZONE)                -- only while this card is on the field
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCountLimit(1,id)                     -- (1,id) = "this effect of <name> once per turn" (shared by all copies)
	                                           -- (1)    = "once per turn" for each copy separately
	e1:SetTarget(s.damtg)
	e1:SetOperation(s.damop)
	c:RegisterEffect(e1)
end
function s.damtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetTargetPlayer(1-tp)                 -- 1-tp = the opponent
	Duel.SetTargetParam(500)
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,500)
end
function s.damop(e,tp,eg,ep,ev,re,r,rp)
	local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM)
	Duel.Damage(p,d,REASON_EFFECT)
end
