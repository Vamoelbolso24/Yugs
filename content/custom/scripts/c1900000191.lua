-- Mr. Mime
-- If this card is Summoned: You can declare 1 card type (Monster, Spell or Trap); while this card is face-up on the
-- field, your opponent cannot target monsters you control with card effects of the declared type.
-- During the End Phase, if you control this Tribute Summoned card: You can change this card to Defense Position,
-- and if you do, destroy 1 Set card your opponent controls.
local s,id=GetID()
local TYPES={TYPE_MONSTER,TYPE_SPELL,TYPE_TRAP}
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end
		local ty=TYPES[Duel.SelectOption(tp,70,71,72)+1]   -- Monster / Spell / Trap
		-- Barrier: lasts while this card stays face-up on the field
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_FIELD)
		e2:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
		e2:SetRange(LOCATION_MZONE)
		e2:SetTargetRange(LOCATION_MZONE,0)
		e2:SetValue(function(ef,re,rp) return rp==1-ef:GetHandlerPlayer() and re:IsActiveType(ty) end)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD)
		c:RegisterEffect(e2)
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetProperty(EFFECT_FLAG_CLIENT_HINT)
		e3:SetDescription(aux.Stringid(id,2+(ty==TYPE_SPELL and 1 or ty==TYPE_TRAP and 2 or 0)))
		e3:SetReset(RESET_EVENT|RESETS_STANDARD)
		c:RegisterEffect(e3)
	end)
	c:RegisterEffect(e1)
	local e1b=e1:Clone() e1b:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e1b)
	local e1c=e1:Clone() e1c:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e1c)
	-- End Phase (each player's): to Defense, destroy a Set card
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,1))
	e4:SetCategory(CATEGORY_POSITION+CATEGORY_DESTROY)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e4:SetCode(EVENT_PHASE+PHASE_END)
	e4:SetRange(LOCATION_MZONE)
	e4:SetCountLimit(1)
	e4:SetCondition(function(e) local c=e:GetHandler() return c:IsSummonType(SUMMON_TYPE_TRIBUTE) and c:IsAttackPos() end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsFacedown,tp,0,LOCATION_ONFIELD,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,nil,1,1-tp,LOCATION_ONFIELD)
	end)
	e4:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsAttackPos()) then return end
		if Duel.ChangePosition(c,POS_FACEUP_DEFENSE)==0 then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
		local g=Duel.SelectMatchingCard(tp,Card.IsFacedown,tp,0,LOCATION_ONFIELD,1,1,nil)
		if #g>0 then Duel.HintSelection(g) Duel.Destroy(g,REASON_EFFECT) end
	end)
	c:RegisterEffect(e4)
end
