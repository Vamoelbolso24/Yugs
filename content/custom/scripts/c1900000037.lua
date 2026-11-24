-- Thunder Stone (Normal Spell)
-- Tribute 1 monster that mentions "Thunder Stone"; Special Summon 1 monster from your GY or Deck that
-- mentions the Tributed monster's name. You cannot Normal or Special Summon monsters with the same name
-- as the Summoned monster for the rest of this turn.
-- (Pikachu mentions Thunder Stone; Raichu mentions Pikachu. Future stones/evolutions can reuse this.)
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(s.cost)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
-- Something in GY/Deck that mentions code and can be Special Summoned
function s.spfilter(c,e,tp,code)
	return c:IsMonster() and c:ListsCode(code) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
-- A face-up monster you control that mentions Thunder Stone, with something to summon for it
function s.cfilter(c,e,tp)
	return c:IsFaceup() and c:ListsCode(id) and c:IsReleasable() and Duel.GetMZoneCount(tp,c)>0
		and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_GRAVE|LOCATION_DECK,0,1,nil,e,tp,c:GetCode())
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_MZONE,0,1,nil,e,tp) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
	local tc=Duel.SelectMatchingCard(tp,s.cfilter,tp,LOCATION_MZONE,0,1,1,nil,e,tp):GetFirst()
	e:SetLabel(tc:GetCode())          -- remember the Tributed monster's name
	Duel.Release(tc,REASON_COST)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end    -- everything was checked in the cost
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_GRAVE|LOCATION_DECK)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local tc=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_GRAVE|LOCATION_DECK,0,1,1,nil,e,tp,e:GetLabel()):GetFirst()
	if not tc or Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)==0 then return end
	-- No more Normal/Special Summons of that name this turn
	local code=tc:GetCode()
	for _,eff in ipairs({EFFECT_CANNOT_SUMMON,EFFECT_CANNOT_SPECIAL_SUMMON,EFFECT_CANNOT_MSET}) do
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_FIELD)
		e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		e1:SetCode(eff)
		e1:SetTargetRange(1,0)
		e1:SetTarget(function(e,c) return c:IsCode(code) end)
		e1:SetReset(RESET_PHASE|PHASE_END)
		Duel.RegisterEffect(e1,tp)
	end
end
