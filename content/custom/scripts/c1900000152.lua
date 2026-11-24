-- Destiny Bond (Normal Trap)
-- If a Zombie Pokemon monster you control is destroyed by an opponent's card and sent to the GY: Send 1 monster
-- your opponent controls to the GY.
-- "Destroyed by an opponent's card" counts BOTH destroyed by battle with their monster, and destroyed by their
-- card effect. (Not targeted: the monster is chosen when it resolves.)
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOGRAVE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_TO_GRAVE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP)
	e1:SetCondition(function(e,tp,eg) return eg:IsExists(s.cfilter,1,nil,tp) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsAbleToGrave,tp,0,LOCATION_MZONE,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOGRAVE,nil,1,1-tp,LOCATION_MZONE)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
		local g=Duel.SelectMatchingCard(tp,Card.IsAbleToGrave,tp,0,LOCATION_MZONE,1,1,nil)
		if #g>0 then
			Duel.HintSelection(g)
			Duel.SendtoGrave(g,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
end
-- my Zombie Pokemon, destroyed on my field by my opponent (their effect, or battle with their monster)
function s.cfilter(c,tp)
	if not (c:IsPreviousControler(tp) and c:IsPreviousLocation(LOCATION_MZONE) and c:IsReason(REASON_DESTROY)) then return false end
	if not (c:IsSetCard(SET_POKEMON) and c:IsRace(RACE_ZOMBIE)) then return false end
	if c:IsReason(REASON_BATTLE) then
		local rc=c:GetReasonCard()
		return rc and rc:IsControler(1-tp)
	end
	return c:IsReason(REASON_EFFECT) and c:GetReasonPlayer()==1-tp
end
