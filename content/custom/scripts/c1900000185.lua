-- Seadra
-- Evolution Summon from "Horsea" (hard once per turn).
-- If Summoned this way: You can add 1 Level 4 or lower Aqua, Sea Serpent or Fish Pokemon from your Deck to your hand.
-- If this card is destroyed by battle: Roll a six-sided die, then place that many Poison Counters on monsters your
-- opponent controls (you choose where each one goes).
local s,id=GetID()
local RACES=RACE_AQUA|RACE_SEASERPENT|RACE_FISH
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000184)   -- from Horsea
	Pokemon.EnablePoisonRule()
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsEvolutionSummoned(e:GetHandler()) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e1)
	-- Destroyed by battle: die roll -> Poison Counters
	local e2=Effect.CreateEffect(c)
	e2:SetCategory(CATEGORY_DICE+CATEGORY_COUNTER)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_DESTROYED)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DICE,nil,0,tp,1)
	end)
	e2:SetOperation(function(e,tp)
		local n=Duel.TossDice(tp,1)
		for i=1,n do
			local g=Duel.GetMatchingGroup(s.pfilter,tp,0,LOCATION_MZONE,nil)
			if #g==0 then break end
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
			local tc=g:Select(tp,1,1,nil):GetFirst()
			tc:AddCounter(COUNTER_POISON,1)
		end
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000184}
s.roll_dice=true
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsRace(RACES) and c:IsLevelBelow(4) and c:IsAbleToHand() end
function s.pfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_POISON,1) end
