-- Rapid Spin (Normal Spell)
-- Discard 1 card, then target 1 Pokemon monster you control that hasn't declared an attack this turn; destroy
-- all Continuous Spells your opponent controls, also the targeted monster cannot declare an attack this turn.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,e:GetHandler()) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.pokefilter(c) return c:IsFaceup() and c:IsSetCard(SET_POKEMON) and c:GetAttackAnnouncedCount()==0 end
function s.contfilter(c) return c:IsFaceup() and c:IsSpell() and c:IsType(TYPE_CONTINUOUS) end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.pokefilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.pokefilter,tp,LOCATION_MZONE,0,1,nil)
		and Duel.IsExistingMatchingCard(s.contfilter,tp,0,LOCATION_ONFIELD,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	Duel.SelectTarget(tp,s.pokefilter,tp,LOCATION_MZONE,0,1,1,nil)
	local g=Duel.GetMatchingGroup(s.contfilter,tp,0,LOCATION_ONFIELD,nil)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
end
function s.activate(e,tp)
	Duel.Destroy(Duel.GetMatchingGroup(s.contfilter,tp,0,LOCATION_ONFIELD,nil),REASON_EFFECT)
	local tc=Duel.GetFirstTarget()
	if tc and tc:IsRelateToEffect(e) then
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e1:SetReset(RESETS_STANDARD_PHASE_END)
		tc:RegisterEffect(e1)
	end
end
