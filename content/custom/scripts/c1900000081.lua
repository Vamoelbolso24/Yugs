-- Earthquake (Move) (Normal Spell)
-- Target 1 Rock monster you control; destroy all other face-up non-WIND monsters on the field whose DEF is
-- equal to or lower than the targeted monster's ATK.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.rockfilter(c) return c:IsFaceup() and c:IsRace(RACE_ROCK) end
-- the monsters it destroys: face-up, not WIND, DEF <= atk, not the targeted one
function s.desfilter(c,atk,tc)
	return c:IsFaceup() and not c:IsAttribute(ATTRIBUTE_WIND) and c:IsDefenseBelow(atk) and c~=tc
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.rockfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.rockfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local tc=Duel.SelectTarget(tp,s.rockfilter,tp,LOCATION_MZONE,0,1,1,nil):GetFirst()
	local g=Duel.GetMatchingGroup(s.desfilter,tp,LOCATION_MZONE,LOCATION_MZONE,nil,tc:GetAttack(),tc)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
end
function s.activate(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	local g=Duel.GetMatchingGroup(s.desfilter,tp,LOCATION_MZONE,LOCATION_MZONE,nil,tc:GetAttack(),tc)
	Duel.Destroy(g,REASON_EFFECT)
end
