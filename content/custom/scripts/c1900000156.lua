-- Hypno
-- Evolution Summon from "Drowzee" (hard once per turn).
-- During your opponent's End Phase: Inflict 300 damage to your opponent for each Set card they control.
-- Once per turn: You can discard 1 card, then target 1 monster your opponent controls; change it to face-down
-- Defense Position. Monsters changed to face-down Defense Position by this effect cannot change their battle
-- positions.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000155)   -- from Drowzee
	-- Damage for Set cards (mandatory)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_PHASE+PHASE_END)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(1-tp) and Duel.IsExistingMatchingCard(Card.IsFacedown,tp,0,LOCATION_ONFIELD,1,nil) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,300)
	end)
	e1:SetOperation(function(e,tp)
		local n=Duel.GetMatchingGroupCount(Card.IsFacedown,tp,0,LOCATION_ONFIELD,nil)   -- counted when it resolves
		if n>0 then Duel.Damage(1-tp,300*n,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
	-- Put a monster to sleep (face-down, locked)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_POSITION)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.filter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.filter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
		local g=Duel.SelectTarget(tp,s.filter,tp,0,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_POSITION,g,1,0,0)
	end)
	e2:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
		if Duel.ChangePosition(tc,POS_FACEDOWN_DEFENSE)==0 then return end
		-- it stays locked in that position while it remains on the field
		local e3=Effect.CreateEffect(e:GetHandler())
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
		e3:SetReset(RESET_EVENT|RESETS_STANDARD&~RESET_TURN_SET)
		tc:RegisterEffect(e3)
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000155}
function s.filter(c) return c:IsFaceup() and c:IsCanTurnSet() end
