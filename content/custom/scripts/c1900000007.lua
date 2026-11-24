-- Charizard
-- Evolution Summon from "Charmeleon". If Summoned this way: You can target 1 monster your opponent controls; destroy it.
-- (Same shape as Charmeleon, c1900000006.lua, with a targeting destroy effect.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000006)   -- EVOLUTION SUMMON from Charmeleon

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetProperty(EFFECT_FLAG_DELAY+EFFECT_FLAG_CARD_TARGET)   -- CARD_TARGET = it targets
	e1:SetCondition(function(e) return Pokemon.IsEvolutionSummoned(e:GetHandler()) end)
	e1:SetTarget(s.destg)
	e1:SetOperation(s.desop)
	c:RegisterEffect(e1)
end
s.listed_names={1900000006}

-- PATTERN: a targeting effect. The target function is called 3 ways:
--   chkc ~= nil : "is this card still a valid target?" (for cards that redirect targets)
--   chk == 0    : "can it be activated?" (is there anything to target?)
--   otherwise   : the player picks the target.
function s.destg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) end
	if chk==0 then return Duel.IsExistingTarget(nil,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
	local g=Duel.SelectTarget(tp,nil,tp,0,LOCATION_MZONE,1,1,nil)   -- (tp,filter,tp, my locations, opponent's locations, min,max)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,1,0,0)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc and tc:IsRelateToEffect(e) then      -- still there and still the same card?
		Duel.Destroy(tc,REASON_EFFECT)
	end
end
