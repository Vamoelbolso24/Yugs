-- Volt Tackle (Normal Spell)
-- Tribute 1 "Pikachu" monster that hasn't declared an attack this turn; inflict damage to your opponent
-- equal to its ATK, and if you do, your opponent discards 1 random card, then if they have any cards
-- left in their hand, they discard 1 more card of their choice.
-- ("Pikachu" monster = a card with Subtypes: Pikachu, checked with c:IsSetCard(SET_PIKACHU).)
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE+CATEGORY_HANDES)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(s.cost)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.cfilter(c)
	return c:IsFaceup() and c:IsSetCard(SET_PIKACHU) and c:GetAttackAnnouncedCount()==0 and c:IsReleasable()
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
	local tc=Duel.SelectMatchingCard(tp,s.cfilter,tp,LOCATION_MZONE,0,1,1,nil):GetFirst()
	e:SetLabel(tc:GetAttack())        -- its ATK while it was on the field
	Duel.Release(tc,REASON_COST)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,e:GetLabel())
	Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,1-tp,2)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if Duel.Damage(1-tp,e:GetLabel(),REASON_EFFECT)<=0 then return end   -- "and if you do"
	local hand=Duel.GetFieldGroup(1-tp,LOCATION_HAND,0)
	if #hand==0 then return end
	Duel.BreakEffect()
	local random=hand:RandomSelect(1-tp,1)                             -- 1 random card
	Duel.SendtoGrave(random,REASON_EFFECT+REASON_DISCARD)
	if Duel.GetFieldGroupCount(1-tp,LOCATION_HAND,0)>0 then
		Duel.BreakEffect()
		Duel.DiscardHand(1-tp,nil,1,1,REASON_EFFECT+REASON_DISCARD)       -- 1 of their choice
	end
end
