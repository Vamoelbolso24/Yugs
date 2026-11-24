-- Beedrill
-- Evolution Summon from "Kakuna" (hard once per turn).
-- Can make a second attack during each Battle Phase.
-- At the end of the Battle Phase, if this card destroyed a monster by battle: You can return it to the
-- hand, and if you do, Special Summon 1 Level 5 or lower Insect Pokemon from your hand, except "Beedrill".
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000019)   -- from Kakuna

	-- PATTERN: "Can make a second attack during each Battle Phase" = EFFECT_EXTRA_ATTACK with value 1.
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_EXTRA_ATTACK)
	e1:SetValue(1)
	c:RegisterEffect(e1)

	-- Remember that it destroyed a monster by battle this turn (a "flag" on the card until the End Phase).
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_BATTLE_DESTROYING)
	e2:SetOperation(function(e) e:GetHandler():RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1) end)
	c:RegisterEffect(e2)

	-- End of the Battle Phase: return and switch
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_TOHAND+CATEGORY_SPECIAL_SUMMON)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsAbleToHand() end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,e:GetHandler(),1,0,0)
	end)
	e3:SetOperation(function(e,tp) Pokemon.ReturnAndSwitch(e,tp,e:GetHandler(),5,id) end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000019}
