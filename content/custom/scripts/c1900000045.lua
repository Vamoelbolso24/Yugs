-- Nidoqueen
-- Evolution Summon from "Nidorina" (hard once per turn).
-- "Nido" monsters you control, except "Nidoqueen", are unaffected by your opponent's Trap effects.
-- If you Summon a "Nido" monster(s): Draw 1 card. You can only activate this effect of "Nidoqueen" once per turn.
-- PATTERN: "If you Summon a ... monster" = an EFFECT_TYPE_FIELD trigger on the summon events,
-- checking the summoned group (eg). Mandatory ("Draw 1 card", not "You can") = TRIGGER_F.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000044)   -- from Nidorina
	Pokemon.AddNidoImmunity(c,TYPE_TRAP)

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1,id)
	e1:SetCondition(s.drcon)
	e1:SetTarget(s.drtg)
	e1:SetOperation(s.drop)
	c:RegisterEffect(e1)
	local e2=e1:Clone() e2:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2)
	local e3=e1:Clone() e3:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e3)
end
s.listed_names={1900000044}
function s.drcon(e,tp,eg)
	return eg:IsExists(function(tc) return tc:IsFaceup() and tc:IsSetCard(SET_NIDO) and tc:IsSummonPlayer(tp) end,1,nil)
end
function s.drtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetTargetPlayer(tp)
	Duel.SetTargetParam(1)
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
end
function s.drop(e,tp,eg,ep,ev,re,r,rp)
	local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM)
	Duel.Draw(p,d,REASON_EFFECT)
end
