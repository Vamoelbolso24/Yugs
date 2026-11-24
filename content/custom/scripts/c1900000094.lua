-- Gym Leader - Blaine (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- When this card is activated: You can discard 1 Spell/Trap; add 1 FIRE Pokemon monster from your Deck to your hand.
-- If you Normal or Special Summon a FIRE Pokemon monster(s): Inflict 400 damage to your opponent.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGymLeader(c,nil,nil,s.actop)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_DAMAGE)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCondition(function(e,tp,eg) return eg:IsExists(s.firepoke,1,nil,tp) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,400)
	end)
	e2:SetOperation(function(e,tp)
		if e:GetHandler():IsRelateToEffect(e) then Duel.Damage(1-tp,400,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e3)
end
function s.firepoke(c,tp) return c:IsFaceup() and c:IsSummonPlayer(tp) and c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_FIRE) end
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_FIRE) and c:IsMonster() and c:IsAbleToHand() end
function s.discard(c) return c:IsSpellTrap() and c:IsDiscardable() end
-- "You can discard 1 Spell/Trap; add 1 FIRE Pokemon": asked when the card resolves
function s.actop(e,tp)
	if not e:GetHandler():IsRelateToEffect(e) then return end
	if not (Duel.IsExistingMatchingCard(s.discard,tp,LOCATION_HAND,0,1,nil)
		and Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil)) then return end
	if not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then return end
	if Duel.DiscardHand(tp,s.discard,1,1,REASON_EFFECT|REASON_DISCARD)==0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
	if #g>0 then
		Duel.SendtoHand(g,nil,REASON_EFFECT)
		Duel.ConfirmCards(1-tp,g)
	end
end
