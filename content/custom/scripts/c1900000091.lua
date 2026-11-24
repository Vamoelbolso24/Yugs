-- Gym Leader - Erika (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- Whenever you gain LP by the effect of a Plant Pokemon monster, your opponent takes damage equal to half the LP gained.
-- Once per turn, when a card or effect is activated that targets a Plant Pokemon monster you control: You can
-- discard 1 Plant monster; negate the activation, and if you do, destroy that card.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGymLeader(c)
	-- LP gain -> damage
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_RECOVER)
	e1:SetRange(LOCATION_SZONE)
	e1:SetCondition(function(e,tp,eg,ep,ev,re)
		return ep==tp and re and re:IsMonsterEffect() and re:GetHandler():IsRace(RACE_PLANT) and re:GetHandler():IsSetCard(SET_POKEMON)
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev)
		Duel.Hint(HINT_CARD,0,id)
		Duel.Damage(1-tp,math.floor(ev/2),REASON_EFFECT)   -- ev = how much LP was gained
	end)
	c:RegisterEffect(e1)
	-- Negate something targeting your Plant Pokemon
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_CHAINING)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp,eg,ep,ev)
		return Duel.IsChainNegatable(ev) and Pokemon.TargetsMine(tp,ev,s.plantpoke)
	end)
	e2:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.discard,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,s.discard,1,1,REASON_COST|REASON_DISCARD)
	end)
	e2:SetTarget(s.negtg)
	e2:SetOperation(s.negop)
	c:RegisterEffect(e2)
end
function s.plantpoke(c) return c:IsSetCard(SET_POKEMON) and c:IsRace(RACE_PLANT) end
function s.discard(c) return c:IsMonster() and c:IsRace(RACE_PLANT) and c:IsDiscardable() end
function s.negtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
	if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
	end
end
function s.negop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then
		Duel.Destroy(eg,REASON_EFFECT)
	end
end
