-- U-Turn (Quick-Play Spell)
-- During your Battle Phase, after an Insect Pokemon you control has battled: Return it to the hand,
-- and if you do, Special Summon from your hand 1 Insect Pokemon with an equal or lower Level but a
-- different name.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetHintTiming(0,TIMING_BATTLE_END+TIMING_BATTLE_STEP_END)
	-- Only in your Battle Phase
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and Duel.IsBattlePhase() end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end

-- A face-up Insect Pokemon you control that has battled this turn, and a replacement in hand for it.
function s.battled(c,e,tp)
	return c:IsFaceup() and c:IsSetCard(SET_POKEMON) and c:IsRace(RACE_INSECT) and c:GetBattledGroupCount()>0
		and c:IsAbleToHand() and Duel.GetMZoneCount(tp,c)>0
		and Duel.IsExistingMatchingCard(Pokemon.InsectFilter,tp,LOCATION_HAND,0,1,nil,e,tp,c:GetLevel(),c:GetCode())
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.battled,tp,LOCATION_MZONE,0,1,nil,e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_MZONE)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RTOHAND)
	local tc=Duel.SelectMatchingCard(tp,s.battled,tp,LOCATION_MZONE,0,1,1,nil,e,tp):GetFirst()
	if tc then Pokemon.ReturnAndSwitch(e,tp,tc,tc:GetLevel(),tc:GetCode()) end
end
