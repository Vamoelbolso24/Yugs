-- Team Rocket - Grunts (Normal Trap)
-- Pay 800 LP; excavate the top 4 cards of your Deck, then Special Summon any "Rattata", "Sandshrew", "Ekans",
-- "Koffing" and "Zubat" among them, also shuffle the rest into the Deck. Monsters Summoned by this effect
-- cannot be Tributed, also banish them when they leave the field.
local s,id=GetID()
-- The monsters it can Summon.
local GRUNTS={1900000027,1900000040,1900000032,1900000175,1900000058}   -- Rattata, Sandshrew, Ekans, Koffing, Zubat
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(Cost.PayLP(800))
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=4 end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,0,tp,LOCATION_DECK)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names=GRUNTS

function s.spfilter(c,e,tp)
	return c:IsCode(table.unpack(GRUNTS)) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.activate(e,tp)
	if Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)<4 then return end
	Duel.ConfirmDecktop(tp,4)                     -- excavate: both players see them
	local g=Duel.GetDecktopGroup(tp,4):Filter(s.spfilter,nil,e,tp)
	local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
	if #g>0 and ft>0 then
		if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=1 end
		-- "any": choose as many as you want (up to your free Monster Zones)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local sg=g:Select(tp,0,math.min(ft,#g),nil)
		for tc in sg:Iter() do
			if Duel.SpecialSummonStep(tc,0,tp,tp,false,false,POS_FACEUP) then
				-- Cannot be Tributed (for a Tribute Summon or anything else)
				local e1=Effect.CreateEffect(e:GetHandler())
				e1:SetType(EFFECT_TYPE_SINGLE)
				e1:SetCode(EFFECT_UNRELEASABLE_SUM)
				e1:SetValue(1)
				e1:SetReset(RESET_EVENT|RESETS_STANDARD)
				tc:RegisterEffect(e1,true)
				local e2=e1:Clone()
				e2:SetCode(EFFECT_UNRELEASABLE_NONSUM)
				tc:RegisterEffect(e2,true)
				-- Banish it when it leaves the field
				local e3=Effect.CreateEffect(e:GetHandler())
				e3:SetType(EFFECT_TYPE_SINGLE)
				e3:SetCode(EFFECT_LEAVE_FIELD_REDIRECT)
				e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
				e3:SetValue(LOCATION_REMOVED)
				e3:SetReset(RESET_EVENT|RESETS_REDIRECT)
				tc:RegisterEffect(e3,true)
			end
		end
		Duel.SpecialSummonComplete()
	end
	Duel.ShuffleDeck(tp)                          -- the rest goes back shuffled
end
