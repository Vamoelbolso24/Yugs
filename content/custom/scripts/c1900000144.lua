-- Tri-Attack (Normal Spell)
-- Activate only if you control "Dodrio" or "Magneton".
-- Reveal 3 Pokemon monsters with different Attributes from your Deck, your opponent randomly banishes 1 of them,
-- and you add the other 2 to your hand. Then, if the banished monster was WATER, LIGHT or FIRE, apply:
-- * WATER: Your opponent cannot activate or Set Spell/Trap cards until your next Standby Phase.
-- * LIGHT: Monsters your opponent controls cannot declare an attack during their next turn.
-- * FIRE: Inflict damage to your opponent equal to the banished monster's ATK.
-- PATTERN: "3 cards with different Attributes" = aux.SelectUnselectGroup with a check that the 3 chosen
-- cards have 3 different Attributes (GetClassCount).
local s,id=GetID()
local DODRIO,MAGNETON=1900000141,1900000137
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_REMOVE+CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(function(e,tp)
		return Duel.IsExistingMatchingCard(aux.FaceupFilter(Card.IsCode,DODRIO,MAGNETON),tp,LOCATION_MZONE,0,1,nil)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=Duel.GetMatchingGroup(s.filter,tp,LOCATION_DECK,0,nil)
		if chk==0 then return aux.SelectUnselectGroup(g,e,tp,3,3,s.rescon,0) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,2,tp,LOCATION_DECK)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names={DODRIO,MAGNETON}
function s.filter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsAbleToHand() end
function s.rescon(sg) return sg:GetClassCount(Card.GetAttribute)==#sg end   -- all different Attributes
function s.activate(e,tp)
	local g=Duel.GetMatchingGroup(s.filter,tp,LOCATION_DECK,0,nil)
	local sg=aux.SelectUnselectGroup(g,e,tp,3,3,s.rescon,1,tp,HINTMSG_CONFIRM)
	if #sg<3 then return end
	Duel.ConfirmCards(1-tp,sg)                   -- reveal them
	local bc=sg:RandomSelect(1-tp,1):GetFirst()  -- the opponent picks 1 at random
	Duel.Remove(bc,POS_FACEUP,REASON_EFFECT)
	sg:RemoveCard(bc)
	Duel.SendtoHand(sg,nil,REASON_EFFECT)
	Duel.ConfirmCards(1-tp,sg)
	if not bc:IsLocation(LOCATION_REMOVED) then return end
	local c=e:GetHandler()
	if bc:IsAttribute(ATTRIBUTE_WATER) then
		-- no Spell/Trap activations or Sets until your next Standby Phase
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_FIELD)
		e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		e1:SetCode(EFFECT_CANNOT_ACTIVATE)
		e1:SetTargetRange(0,1)
		e1:SetValue(function(e,re) return re:IsHasType(EFFECT_TYPE_ACTIVATE) end)
		e1:SetReset(RESET_PHASE|PHASE_STANDBY|RESET_SELF_TURN)
		Duel.RegisterEffect(e1,tp)
		local e2=e1:Clone()
		e2:SetCode(EFFECT_CANNOT_SSET)
		e2:SetValue(1)
		e2:SetTarget(aux.TRUE)
		Duel.RegisterEffect(e2,tp)
	end
	if bc:IsAttribute(ATTRIBUTE_LIGHT) then
		-- their monsters can't attack during their next turn
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_FIELD)
		e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e3:SetTargetRange(0,LOCATION_MZONE)
		e3:SetReset(RESET_PHASE|PHASE_END|RESET_OPPO_TURN)
		Duel.RegisterEffect(e3,tp)
	end
	if bc:IsAttribute(ATTRIBUTE_FIRE) then
		Duel.Damage(1-tp,math.max(bc:GetAttack(),0),REASON_EFFECT)
	end
end
