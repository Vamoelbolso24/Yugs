-- Sandslash
-- Evolution Summon from "Sandshrew" (hard once per turn).
-- Once per turn: You can discard 1 card, then declare a monster type (Pyro, Thunder, Rock, or Machine);
-- destroy all monsters on the field of the declared type.
-- This card cannot declare an attack the turn you activate this effect.
-- PATTERN: "declare a Type" = Duel.AnnounceRace(player, how many, which types are allowed).
local s,id=GetID()
local TYPES=RACE_PYRO|RACE_THUNDER|RACE_ROCK|RACE_MACHINE
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000040)   -- from Sandshrew

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCost(s.cost)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
s.listed_names={1900000040}

-- Face-up monsters of the allowed types
function s.typefilter(c) return c:IsFaceup() and c:IsRace(TYPES) end

function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	-- can't use it after this card already attacked this turn (it couldn't keep the "no attack" promise)
	if chk==0 then return c:GetAttackAnnouncedCount()==0
		and Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
	Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	-- "This card cannot declare an attack the turn you activate this effect"
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_OATH)
	e1:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
	e1:SetReset(RESETS_STANDARD_PHASE_END)
	c:RegisterEffect(e1)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	-- only offer it if a monster of one of the 4 types is on the field
	local g=Duel.GetMatchingGroup(s.typefilter,tp,LOCATION_MZONE,LOCATION_MZONE,nil)
	if chk==0 then return #g>0 end
	-- only let the player declare types that are actually on the field
	local present=0
	for tc in g:Iter() do present=present|(tc:GetRace()&TYPES) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RACE)
	local race=Duel.AnnounceRace(tp,1,present)
	e:SetLabel(race)
	local dg=Duel.GetMatchingGroup(aux.FaceupFilter(Card.IsRace,race),tp,LOCATION_MZONE,LOCATION_MZONE,nil)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,dg,#dg,0,0)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local dg=Duel.GetMatchingGroup(aux.FaceupFilter(Card.IsRace,e:GetLabel()),tp,LOCATION_MZONE,LOCATION_MZONE,nil)
	Duel.Destroy(dg,REASON_EFFECT)
end
